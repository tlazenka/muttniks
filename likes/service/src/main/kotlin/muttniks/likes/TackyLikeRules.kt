package muttniks.likes

import tacky.KnowledgeBase
import tacky.Term
import tacky.asTerm

class TackyLikeRules(
    private val networkBurstThreshold: Int = 10,
    private val coordinatedSessionThreshold: Int = 5,
    private val windowSeconds: Long = 10,
    private val newSessionSeconds: Long = 60,
) : LikeRules {
    override fun evaluate(context: LikeContext): LikeDecision {
        val v = context.current
        val prior = context.recentLikes.filter { it.likeId != v.likeId }
        val withinWindow = prior.filter { v.epochSecond - it.epochSecond in 0..windowSeconds }

        val facts = buildList {
            add(Term.Fact("current_like", Term.Lit(v.likeId)))
            if (prior.any { it.petId == v.petId && it.session == v.session })
                add(Term.Fact("same_session_same_pet", Term.Lit(v.likeId)))
            if (withinWindow.count { it.network == v.network } + 1 >= networkBurstThreshold)
                add(Term.Fact("network_burst", Term.Lit(v.likeId)))
            val newSessions =
                (withinWindow + v)
                    .filter {
                        it.petId == v.petId &&
                            it.epochSecond - it.sessionCreatedAtEpochSecond <= newSessionSeconds
                    }
                    .map { it.session }
                    .distinct()
                    .size
            if (newSessions >= coordinatedSessionThreshold)
                add(Term.Fact("coordinated_new_sessions", Term.Lit(v.likeId)))
        }

        val like = Term.Var("Like")
        val reason = Term.Var("Reason")
        val suspicious = "suspicious".asTerm
        val rules =
            listOf(
                "same_session_same_pet".asTerm[like] implies
                    suspicious[like, Term.Lit("repeated-session")],
                "network_burst".asTerm[like] implies
                    suspicious[like, Term.Lit("rapid-network-burst")],
                "coordinated_new_sessions".asTerm[like] implies
                    suspicious[like, Term.Lit("coordinated-new-sessions")],
            )
        val kb = KnowledgeBase(facts + rules)
        val reasons = buildSet {
            val answers = kb.ask(suspicious[Term.Lit(v.likeId), reason])
            while (answers.hasNext()) {
                val answer = answers.next()
                answer["Reason"]?.extractValue<String>()?.let(::add)
            }
        }
        return LikeDecision(
            if (reasons.isEmpty()) Disposition.ACCEPTED else Disposition.SUSPICIOUS,
            reasons,
        )
    }
}
