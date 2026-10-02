package tacky

import kotlin.test.*

class LogicKitTests {

    @Test
    fun testConstantFacts() {
        val kb =
            KnowledgeBase(
                listOf(
                    Term.Fact("<", Term.Lit(0), Term.Lit(1)),
                    Term.Fact("<", Term.Lit(1), Term.Lit(2)),
                    Term.Fact("<", Term.Lit(2), Term.Lit(3)),
                )
            )
        val answers0 = kb.ask(Term.Fact("<", Term.Lit(0), Term.Lit(1))).toList()
        assertEquals(answers0.size, 1)
        assertEquals(answers0[0], mapOf())
        val answers1 = kb.ask(Term.Fact("<", Term.Lit(2), Term.Lit(3))).toList()
        assertEquals(answers1.size, 1)
        assertEquals(answers1[0], mapOf())
        val answers2 = kb.ask(Term.Fact("<", Term.Lit(0), Term.Lit(3))).toList()
        assertEquals(answers2.size, 0)
    }

    @Test
    fun testExtractValue() {
        val kotlinValue = listOf(1, 2, 3)
        val atom: Term = Term.Lit(kotlinValue)
        assertEquals(atom.extractValue<kotlin.collections.List<Int>>(), kotlinValue)
        assertNull(atom.extractValue<Int>())
        val fact: Term = Term.Fact("hello")
        assertNull(fact.extractValue<String>())
    }

    @Test
    fun testFactsWithVariables() {
        val kb =
            KnowledgeBase(
                listOf(
                    Term.Fact("<", Term.Lit(0), Term.Lit(1)),
                    Term.Fact("<", Term.Lit(1), Term.Lit(2)),
                    Term.Fact("<", Term.Lit(2), Term.Lit(3)),
                )
            )
        val answers0 = kb.ask(Term.Fact("<", Term.Lit(0), Term.Var("x"))).toList()
        assertEquals(answers0.size, 1)
        assertEquals(answers0[0], mapOf("x" to Term.Lit(1)))
        val answers1 = kb.ask(Term.Fact("<", Term.Var("x"), Term.Var("y"))).toList()
        assertEquals(answers1.size, 3)
        assertTrue(answers1.any { it["x"] == Term.Lit(0) && it["y"] == Term.Lit(1) })
        assertTrue(answers1.any { it["x"] == Term.Lit(1) && it["y"] == Term.Lit(2) })
        assertTrue(answers1.any { it["x"] == Term.Lit(2) && it["y"] == Term.Lit(3) })
    }

    @Test
    fun testSimpleDeductions() {
        val kb =
            KnowledgeBase(
                listOf(
                    Term.Fact("play", "mia".asTerm),
                    Term.Rule("happy", "mia".asTerm) {
                        Term.Fact("play", "mia".asTerm)
                    },
                )
            )
        val answers0 = kb.ask(Term.Fact("happy", "mia".asTerm)).toList()
        assertEquals(answers0.size, 1)
        assertEquals(answers0[0], mapOf())
        val answers1 = kb.ask(Term.Fact("happy", Term.Var("who"))).toList()
        assertEquals(answers1.size, 1)
        assertEquals(answers1[0], mapOf("who" to "mia".asTerm))
    }

    @Test
    fun testDisjunction() {
        val x: Term = Term.Var("x")
        val kb =
            KnowledgeBase(
                listOf(
                    Term.Fact("hot", "fire".asTerm),
                    Term.Fact("cold", "ice".asTerm),
                    Term.Rule("painful", x) {
                        Term.Fact("hot", x) or Term.Fact("cold", x)
                    },
                )
            )
        val answers = kb.ask(Term.Fact("painful", x)).toList()
        assertEquals(answers.size, 2)
        val results = setOf(answers.mapNotNull { it["x"] }).flatten()
        assertTrue(results.contains("fire".asTerm))
        assertTrue(results.contains("ice".asTerm))
    }

    @Test
    fun testRecursion() {
        val x: Term = Term.Var("x")
        val y: Term = Term.Var("y")
        val z: Term = Term.Var("z")
        val zero: Term = "zero".asTerm

        fun succ(x: Term): Term = Term.Fact("succ", x)

        fun nat(value: Int): Term {
            return if (value == 0) {
                zero
            } else {
                succ(nat(value = value - 1))
            }
        }
        val kb =
            KnowledgeBase(
                listOf(
                    Term.Fact("diff", zero, x, x),
                    Term.Fact("diff", x, zero, x),
                    Term.Rule("diff", succ(x), succ(y), z) {
                        Term.Fact("diff", x, y, z)
                    },
                )
            )
        val query: Term = Term.Fact("diff", nat(value = 2), nat(value = 4), Term.Var("result"))
        val answers = kb.ask(query)
        val answer = answers.next()
        assertNotNull(answer)
        assertEquals(answer["result"], nat(value = 2))
    }

    @Test
    fun testBacktracking() {
        val x: Term = Term.Var("x")
        val y: Term = Term.Var("y")
        val z: Term = Term.Var("z")
        val w: Term = Term.Var("w")
        val kb =
            KnowledgeBase(
                listOf(
                    Term.Fact("link", "0".asTerm, "1".asTerm),
                    Term.Fact("link", "1".asTerm, "2".asTerm),
                    Term.Fact("link", "2".asTerm, "4".asTerm),
                    Term.Fact("link", "1".asTerm, "3".asTerm),
                    Term.Fact("link", "3".asTerm, "4".asTerm),
                    Term.Rule("path", x, y, Term.Fact("c", x, Term.Fact("c", y, "nil".asTerm))) {
                        Term.Fact("link", x, y)
                    },
                    Term.Rule("path", x, y, Term.Fact("c", x, w)) {
                        Term.Fact("link", x, z) and Term.Fact("path", z, y, w)
                    },
                )
            )
        val query: Term = Term.Fact("path", "0".asTerm, "4".asTerm, Term.Var("nodes"))
        val answers = kb.ask(query).toList()
        // There should be two paths from 0 to 4.
        assertEquals(answers.size, 2)
        // All paths should bind the variable `nodes`.
        assertNotNull(answers[0]["nodes"])
        assertNotNull(answers[1]["nodes"])
    }

    @Test
    fun testLitSyntax() {
        val play: Term = "play".asTerm
        val mia: Term = "mia".asTerm
        val happy: Term = "happy".asTerm
        val who = Term.Var("who")
        val kb =
            KnowledgeBase(
                listOf(
                    play[mia],
                    (play[mia] and play[mia]) implies happy[mia],
                )
            )
        val answers0 = kb.ask(happy[mia]).toList()
        assertEquals(answers0.size, 1)
        assertEquals(answers0[0], mapOf())
        val answers1 = kb.ask(happy[who]).toList()
        assertEquals(answers1.size, 1)
        assertEquals(answers1[0], mapOf("who" to mia))
        assertEquals(answers1[0]["who"], mia)
        assertEquals(answers1[0][who.value], mia)
        assertEquals(
            (play[mia] and play[mia]) implies happy[mia],
            happy[mia] rightTack (play[mia] and play[mia]),
        )
        assertEquals(
            (play[mia] and play[mia]) implies happy[mia],
            happy[mia] rightTack (play[mia] and play[mia]),
        )
    }
}
