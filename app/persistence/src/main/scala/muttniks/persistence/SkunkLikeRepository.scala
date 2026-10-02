package muttniks.persistence

import cats.effect.{IO, Resource}
import muttniks.domain.{LikeCounts, LikeObservation}
import skunk.*
import skunk.codec.all.*
import skunk.implicits.*

final class SkunkLikeRepository(session: Resource[IO, Session[IO]]):
  private val insertC = sql"""insert into pet_likes
    (like_id, pet_id, anonymous_session, network_bucket, occurred_at, session_created_at)
    values ($text::uuid, $int8, $text, $text, to_timestamp($int8), to_timestamp($int8))""".command
  private val recentQ = sql"""select like_id::text, pet_id, anonymous_session, network_bucket,
    extract(epoch from occurred_at)::bigint, extract(epoch from session_created_at)::bigint
    from pet_likes where occurred_at <= to_timestamp($int8)
    order by occurred_at desc limit $int4""".query(text *: int8 *: text *: text *: int8 *: int8)
  private val classifyC = sql"""update pet_likes set classification=$text,
    like_reasons=case when $text = '' then array[]::text[] else string_to_array($text, chr(31)) end
    where like_id=$text::uuid""".command
  private val countsQ = sql"""select count(*), count(*) filter (where classification='accepted')
    from pet_likes where pet_id=$int8""".query(int8 *: int8)

  def insertPending(v: LikeObservation): IO[Unit] =
    session.use(
      _.execute(insertC)((v.likeId, v.petId, v.session, v.network, v.epochSecond, v.sessionCreatedAtEpochSecond)).void
    )

  def recent(beforeOrAtEpochSecond: Long, limit: Int = 100): IO[List[LikeObservation]] =
    session.use(_.execute(recentQ)((beforeOrAtEpochSecond, limit))).map(_.map(LikeObservation.apply.tupled))

  def classify(likeId: String, decision: String, reasons: Seq[String]): IO[Unit] =
    session.use(_.execute(classifyC)((decision, reasons.mkString("\u001f"), reasons.mkString("\u001f"), likeId)).void)

  def counts(petId: Long): IO[LikeCounts] =
    session.use(_.unique(countsQ)(petId)).map(LikeCounts.apply.tupled)
