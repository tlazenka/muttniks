package muttniks.domain

final case class LikeObservation(
    likeId: String,
    petId: Long,
    session: String,
    network: String,
    epochSecond: Long,
    sessionCreatedAtEpochSecond: Long
)

final case class LikeCounts(raw: Long, trusted: Long)
