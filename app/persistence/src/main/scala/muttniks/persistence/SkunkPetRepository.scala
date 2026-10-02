package muttniks.persistence

import cats.effect.{IO, Resource}
import muttniks.domain.PetListing
import skunk.*
import skunk.codec.all.*
import skunk.implicits.*

final class SkunkPetRepository(session: Resource[IO, Session[IO]]):
  private val listingCodec = (int8 *: text.opt *: text.opt *: text.opt).to[PetListing]
  private val findQ = sql"select id, name, adopter, image_url from pets where id = $int8".query(listingCodec)
  private val pageQ =
    sql"select id, name, adopter, image_url from pets order by id limit $int4 offset $int8".query(listingCodec)
  private val countQ = sql"select count(*) from pets".query(int8)

  def find(id: Long): IO[Option[PetListing]] = session.use(_.option(findQ)(id))
  def page(offset: Long, limit: Int): IO[List[PetListing]] = session.use(_.execute(pageQ)((limit, offset)))
  def count: IO[Long] = session.use(_.unique(countQ))
