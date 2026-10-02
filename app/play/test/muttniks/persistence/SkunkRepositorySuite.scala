package muttniks.persistence

import cats.effect.{IO, Resource}
import cats.effect.unsafe.implicits.global
import munit.FunSuite
import muttniks.controllers.MockDatabase
import natchez.Trace.Implicits.noop
import skunk.*
import skunk.codec.all.*
import skunk.implicits.*

class SkunkRepositorySuite extends FunSuite:
  private val host = sys.env.getOrElse("DATABASE_HOST", "localhost")
  private val port = sys.env.get("DATABASE_PORT").fold(5432)(_.toInt)
  private val user = sys.env.getOrElse("DATABASE_USER", "muttniks")
  private val database = sys.env.getOrElse("DATABASE_NAME", "muttniks")
  private val password = sys.env.getOrElse("DATABASE_PASSWORD", "muttniks")

  private val session: Resource[IO, Session[IO]] = Session.single[IO](host = host, port = port, user = user, database = database, password = Some(password))
  private val repo = SkunkPetRepository(session)
  private val reset = session.use(_.execute(sql"truncate table pet_likes, pets".command)).void
  private val seed = sql"insert into pets(id,name,adopter,image_url) values($int8,${text.opt},${text.opt},${text.opt})".command

  override def beforeAll(): Unit = MockDatabase.resetAndEvolve()
  override def beforeEach(context: BeforeEach): Unit = reset.unsafeRunSync()

  test("missing pet returns None"):
    assertEquals(repo.find(1).unsafeRunSync(), None)

  test("find gets"):
    session.use { s =>
      s.execute(seed)((1L, Some("Laika"), None, None)) *>
        s.execute(seed)((2L, Some("Strelka"), Some("0x" + "11" * 20), Some("/strelka.jpg")))
    }.unsafeRunSync()
    assertEquals(repo.find(2).unsafeRunSync().flatMap(_.name), Some("Strelka"))
    assertEquals(repo.count.unsafeRunSync(), 2L)
    assertEquals(repo.page(0, 1).unsafeRunSync().map(_.id), List(1L))
    assertEquals(repo.page(1, 1).unsafeRunSync().map(_.id), List(2L))
