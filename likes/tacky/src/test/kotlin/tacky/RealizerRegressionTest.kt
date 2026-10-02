package tacky

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class RealizerRegressionTest {
    @Test
    fun `unknown predicate has no answers instead of throwing`() {
        val knowledge = KnowledgeBase(Term.Fact("known", Term.Lit("value")))
        val answers = knowledge.ask(Term.Fact("unknown", Term.Var("X")))

        assertFalse(answers.hasNext())
    }

    @Test
    fun `rule whose body predicate has no clauses has no answers`() {
        val like = Term.Var("Like")
        val reason = Term.Var("Reason")
        val suspicious = "suspicious".asTerm
        val knowledge =
            KnowledgeBase(
                "same_session_same_pet".asTerm[like] implies
                    suspicious[like, Term.Lit("repeated-session")]
            )

        val answers = knowledge.ask(suspicious[Term.Lit("v-normal"), reason])

        assertFalse(answers.hasNext())
        assertEquals(emptyList(), answers.asSequence().toList())
    }
}
