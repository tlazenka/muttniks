package muttniks.controllers

import cats.effect.{IO, Resource}
import cats.effect.unsafe.IORuntime
import com.typesafe.config.Config
import muttniks.persistence.{SkunkChainSyncRepository, SkunkPetRepository, SkunkLikeRepository}
import natchez.Trace
import natchez.Trace.Implicits.noop
import skunk.Session

final class SkunkDatabase(config: Config):
  given runtime: IORuntime = IORuntime.global
  given trace: Trace[IO] = noop

  private val pg = config.getConfig("muttniks.postgres")
  val session: Resource[IO, Session[IO]] = Session.single[IO](
    host = pg.getString("host"),
    port = pg.getInt("port"),
    user = pg.getString("user"),
    database = pg.getString("database"),
    password = Some(pg.getString("password"))
  )

  val pets = SkunkPetRepository(session)
  val likes = SkunkLikeRepository(session)
  def sync(chainId: Long, address: String) = SkunkChainSyncRepository(session, chainId, address)
