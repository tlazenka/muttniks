package muttniks.likes

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class LikeRulesTest {
    private val rules = TackyLikeRules(networkBurstThreshold = 3, coordinatedSessionThreshold = 3)

    private fun like(
        id: String,
        pet: Long = 32,
        session: String,
        network: String = "n1",
        at: Long = 100,
        created: Long = at,
    ) = Like(id, pet, session, network, at, created)

    @Test
    fun acceptsOrdinaryLike() {
        assertEquals(
            LikeDecision(Disposition.ACCEPTED, emptySet()),
            rules.evaluate(
                LikeContext(
                    like(
                        "v1",
                        session = "s1",
                    ),
                    emptyList(),
                )
            ),
        )
    }

    @Test
    fun detectsRepeatedSessionOnSamePet() {
        val d =
            rules.evaluate(
                LikeContext(
                    like("v2", session = "s1", at = 101),
                    listOf(like("v1", session = "s1")),
                )
            )
        assertEquals(setOf("repeated-session"), d.reasons)
    }

    @Test
    fun sameSessionOnDifferentPetIsNotARepeat() {
        val d =
            rules.evaluate(
                LikeContext(
                    like("v2", pet = 32, session = "s1", at = 101),
                    listOf(like("v1", pet = 33, session = "s1")),
                )
            )
        assertTrue("repeated-session" !in d.reasons)
    }

    @Test
    fun networkBelowThresholdIsAcceptedForBurstRule() {
        val d =
            rules.evaluate(
                LikeContext(
                    like("v2", session = "s2", at = 101),
                    listOf(like("v1", session = "s1")),
                )
            )
        assertTrue("rapid-network-burst" !in d.reasons)
    }

    @Test
    fun detectsNetworkBurst() {
        val d =
            rules.evaluate(
                LikeContext(
                    like("v3", session = "s3", at = 102),
                    listOf(like("v1", session = "s1"), like("v2", session = "s2", at = 101)),
                )
            )
        assertTrue("rapid-network-burst" in d.reasons)
    }

    @Test
    fun detectsCoordinatedNewSessions() {
        val d =
            rules.evaluate(
                LikeContext(
                    like("v3", session = "s3", at = 102, created = 102),
                    listOf(
                        like("v1", session = "s1", created = 100),
                        like("v2", session = "s2", at = 101, created = 101),
                    ),
                )
            )
        assertTrue("coordinated-new-sessions" in d.reasons)
    }

    @Test
    fun returnsAllApplicableReasons() {
        val prior =
            listOf(
                like("v1", session = "s1", created = 100),
                like("v2", session = "s2", at = 101, created = 101),
                like("v3", session = "s3", at = 102, created = 102),
            )
        val d =
            rules.evaluate(LikeContext(like("v4", session = "s1", at = 103, created = 103), prior))
        assertEquals(
            setOf("repeated-session", "rapid-network-burst", "coordinated-new-sessions"),
            d.reasons,
        )
    }

    @Test
    fun recentLikeOrderDoesNotChangeDecision() {
        val prior =
            listOf(
                like("v1", session = "s1", created = 100),
                like("v2", session = "s2", at = 101, created = 101),
            )
        val current = like("v3", session = "s1", at = 102, created = 102)
        assertEquals(
            rules.evaluate(LikeContext(current, prior)),
            rules.evaluate(LikeContext(current, prior.reversed())),
        )
    }

    @Test
    fun duplicateObservationDoesNotDuplicateReasons() {
        val historical = like("v1", session = "s1", created = 100)
        val d =
            rules.evaluate(
                LikeContext(like("v2", session = "s1", at = 101), listOf(historical, historical))
            )
        assertEquals(1, d.reasons.count { it == "repeated-session" })
    }
}
