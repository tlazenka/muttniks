package tacky

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class KnowledgeBaseTests {

    @Test
    fun testMerge() {
        val kb1 =
            KnowledgeBase(
                listOf(
                    Term.Fact("foo", "bar".asTerm),
                    Term.Rule("foo", Term.Var("x")) {
                        Term.Fact("foo", Term.Var("x"))
                    },
                    Term.Lit(12),
                    Term.Lit(13),
                )
            )
        val kb2 =
            KnowledgeBase(
                listOf(
                    Term.Fact("foo", "bar".asTerm),
                    Term.Rule("foo", Term.Var("y")) {
                        Term.Fact("foo", Term.Var("y"))
                    },
                    Term.Lit(12),
                    Term.Lit(14),
                )
            )
        val knowledge = (kb1 + kb2).iterator().asSequence().toList()
        assertTrue(knowledge.contains(Term.Fact("foo", "bar".asTerm)))
        assertTrue(
            knowledge.contains(Term.Rule("foo", Term.Var("x")) { Term.Fact("foo", Term.Var("x")) })
        )
        assertTrue(
            knowledge.contains(Term.Rule("foo", Term.Var("y")) { Term.Fact("foo", Term.Var("y")) })
        )
        assertTrue(knowledge.contains(Term.Lit(12)))
        assertTrue(knowledge.contains(Term.Lit(13)))
        assertTrue(knowledge.contains(Term.Lit(14)))
        assertEquals(knowledge.filter { it == Term.Fact("foo", "bar".asTerm) }.count(), 1)
        assertEquals(knowledge.filter { it == Term.Lit(12) }.count(), 1)
    }
}
