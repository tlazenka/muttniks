package muttniks.likes

data class Like(
    val likeId: String,
    val petId: Long,
    val session: String,
    val network: String,
    val epochSecond: Long,
    val sessionCreatedAtEpochSecond: Long = epochSecond,
)

data class LikeContext(val current: Like, val recentLikes: List<Like>)

enum class Disposition {
    ACCEPTED,
    SUSPICIOUS,
}

data class LikeDecision(val disposition: Disposition, val reasons: Set<String>)

interface LikeRules {
    fun evaluate(context: LikeContext): LikeDecision
}
