package tacky

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class DslTests {

    @Test
    fun testMergeDsl() {
        val kb1 = knowledgeBase {
            knowledge {
                +fact {
                    name = "foo"
                    arguments {
                        +fact {
                            name = "bar"
                        }
                    }
                }
                +rule {
                    name = "foo"
                    arguments {
                        +`var` {
                            value = "x"
                        }
                    }
                    body = fact {
                        name = "foo"
                        arguments {
                            +`var` {
                                value = "x"
                            }
                        }
                    }
                }
                +lit {
                    value = 12
                }
                +lit {
                    value = 13
                }
            }
        }
        val kb2 = knowledgeBase {
            knowledge {
                +fact {
                    name = "foo"
                    arguments {
                        +fact {
                            name = "bar"
                        }
                    }
                }
                +rule {
                    name = "foo"
                    arguments {
                        +`var` {
                            value = "y"
                        }
                    }
                    body = fact {
                        name = "foo"
                        arguments {
                            +`var` {
                                value = "y"
                            }
                        }
                    }
                }
                +lit {
                    value = 12
                }
                +lit {
                    value = 14
                }
            }
        }

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

    @Test
    fun testFactsWithVariablesDsl() {
        val kb = knowledgeBase {
            knowledge {
                +fact {
                    name = "<"
                    arguments {
                        +lit {
                            value = 0
                        }
                        +lit {
                            value = 1
                        }
                    }
                }
                +fact {
                    name = "<"
                    arguments {
                        +lit {
                            value = 1
                        }
                        +lit {
                            value = 2
                        }
                    }
                }
                +fact {
                    name = "<"
                    arguments {
                        +lit {
                            value = 2
                        }
                        +lit {
                            value = 3
                        }
                    }
                }
            }
        }
        val answers0 =
            kb.ask(
                    fact {
                        name = "<"
                        arguments {
                            +lit {
                                value = 0
                            }
                            +`var` {
                                value = "x"
                            }
                        }
                    }
                )
                .toList()
        assertEquals(answers0.size, 1)
        assertEquals(answers0[0], mapOf("x" to Term.Lit(1)))
        val answers1 =
            kb.ask(
                    fact {
                        name = "<"
                        arguments {
                            +`var` {
                                value = "x"
                            }
                            +`var` {
                                value = "y"
                            }
                        }
                    }
                )
                .toList()
        assertEquals(answers1.size, 3)
        assertTrue(answers1.any { it["x"] == Term.Lit(0) && it["y"] == Term.Lit(1) })
        assertTrue(answers1.any { it["x"] == Term.Lit(1) && it["y"] == Term.Lit(2) })
        assertTrue(answers1.any { it["x"] == Term.Lit(2) && it["y"] == Term.Lit(3) })
    }

    @Test
    fun testSimpleDeductionsDsl() {
        val kb = knowledgeBase {
            knowledge {
                +fact {
                    name = "play"
                    arguments {
                        +fact {
                            name = "mia"
                        }
                    }
                }
                +rule {
                    name = "happy"
                    arguments {
                        +fact {
                            name = "mia"
                        }
                    }
                    body = fact {
                        name = "play"
                        arguments {
                            +fact {
                                name = "mia"
                            }
                        }
                    }
                }
            }
        }
        val answers0 =
            kb.ask(
                    fact {
                        name = "happy"
                        arguments {
                            +fact {
                                name = "mia"
                            }
                        }
                    }
                )
                .toList()
        assertEquals(answers0.size, 1)
        assertEquals(answers0[0], mapOf())

        val answers1 =
            kb.ask(
                    fact {
                        name = "happy"
                        arguments {
                            +`var` {
                                value = "who"
                            }
                        }
                    }
                )
                .toList()
        assertEquals(answers1.size, 1)
        assertEquals(answers1[0], mapOf("who" to "mia".asTerm))
    }

    @Test
    fun testDisjunctionDsl() {
        val x = `var` {
            value = "x"
        }
        val kb = knowledgeBase {
            knowledge {
                +fact {
                    name = "hot"
                    arguments {
                        +fact {
                            name = "fire"
                        }
                    }
                }
                +fact {
                    name = "cold"
                    arguments {
                        +fact {
                            name = "ice"
                        }
                    }
                }
                +rule {
                    name = "painful"
                    arguments {
                        +x
                    }
                    body =
                        fact {
                            name = "hot"
                            arguments {
                                +x
                            }
                        } or
                            fact {
                                name = "cold"
                                arguments {
                                    +x
                                }
                            }
                }
            }
        }

        val answers = kb.ask(Term.Fact("painful", x)).toList()
        assertEquals(answers.size, 2)
        val results = setOf(answers.mapNotNull { it["x"] }).flatten()
        assertTrue(results.contains("fire".asTerm))
        assertTrue(results.contains("ice".asTerm))
    }

    @Test
    fun testRecursionDsl() {
        val x: Term = `var` { value = "x" }
        val y: Term = `var` { value = "y" }
        val z: Term = `var` { value = "z" }
        val zero: Term = fact { name = "zero" }

        fun succ(x: Term): Term = fact {
            name = "succ"
            arguments {
                +x
            }
        }

        fun nat(value: Int): Term {
            return if (value == 0) {
                zero
            } else {
                succ(nat(value = value - 1))
            }
        }
        val kb = knowledgeBase {
            knowledge {
                +fact {
                    name = "diff"
                    arguments {
                        +zero
                        +x
                        +x
                    }
                }
                +fact {
                    name = "diff"
                    arguments {
                        +x
                        +zero
                        +x
                    }
                }
                +rule {
                    name = "diff"
                    arguments {
                        +succ(x)
                        +succ(y)
                        +z
                    }
                    body = fact {
                        name = "diff"
                        arguments {
                            +x
                            +y
                            +z
                        }
                    }
                }
            }
        }

        val query: Term = fact {
            name = "diff"
            arguments {
                +nat(2)
                +nat(4)
                +`var` {
                    value = "result"
                }
            }
        }

        val answers = kb.ask(query)
        val answer = answers.next()
        assertNotNull(answer)
        assertEquals(answer["result"], nat(value = 2))
    }

    @Test
    fun testBacktrackingDsl() {
        val x: Term = `var` { value = "x" }
        val y: Term = `var` { value = "y" }
        val z: Term = `var` { value = "z" }
        val w: Term = `var` { value = "w" }
        val kb = knowledgeBase {
            knowledge {
                +fact {
                    name = "link"
                    arguments {
                        +fact {
                            name = "0"
                        }
                        +fact {
                            name = "1"
                        }
                    }
                }
                +fact {
                    name = "link"
                    arguments {
                        +fact {
                            name = "1"
                        }
                        +fact {
                            name = "2"
                        }
                    }
                }
                +fact {
                    name = "link"
                    arguments {
                        +fact {
                            name = "2"
                        }
                        +fact {
                            name = "4"
                        }
                    }
                }
                +fact {
                    name = "link"
                    arguments {
                        +fact {
                            name = "1"
                        }
                        +fact {
                            name = "3"
                        }
                    }
                }
                +fact {
                    name = "link"
                    arguments {
                        +fact {
                            name = "3"
                        }
                        +fact {
                            name = "4"
                        }
                    }
                }
                +rule {
                    name = "path"
                    arguments {
                        +x
                        +y
                        +fact {
                            name = "c"
                            arguments {
                                +x
                                +fact {
                                    name = "c"
                                    arguments {
                                        +y
                                        +fact {
                                            name = "nil"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    body = fact {
                        name = "link"
                        arguments {
                            +x
                            +y
                        }
                    }
                }
                +rule {
                    name = "path"
                    arguments {
                        +x
                        +y
                        +fact {
                            name = "c"
                            arguments {
                                +x
                                +w
                            }
                        }
                    }
                    body =
                        fact {
                            name = "link"
                            arguments {
                                +x
                                +z
                            }
                        } and
                            fact {
                                name = "path"
                                arguments {
                                    +z
                                    +y
                                    +w
                                }
                            }
                }
            }
        }

        val query: Term = fact {
            name = "path"
            arguments {
                +fact {
                    name = "0"
                }
                +fact {
                    name = "4"
                }
                +`var` {
                    value = "nodes"
                }
            }
        }
        val answers = kb.ask(query).toList()
        // There should be two paths from 0 to 4.
        assertEquals(answers.size, 2)
        // All paths should bind the variable `nodes`.
        assertNotNull(answers[0]["nodes"])
        assertNotNull(answers[1]["nodes"])
    }

    @Test
    fun testDslEquality() {
        val x0: Term = `var` { value = "x" }
        val y0: Term = `var` { value = "y" }
        val z0: Term = `var` { value = "z" }
        val w0: Term = `var` { value = "w" }
        val kb0 = knowledgeBase {
            knowledge {
                +fact {
                    name = "link"
                    arguments {
                        +fact {
                            name = "0"
                        }
                        +fact {
                            name = "1"
                        }
                    }
                }
                +fact {
                    name = "link"
                    arguments {
                        +fact {
                            name = "1"
                        }
                        +fact {
                            name = "2"
                        }
                    }
                }
                +fact {
                    name = "link"
                    arguments {
                        +fact {
                            name = "2"
                        }
                        +fact {
                            name = "4"
                        }
                    }
                }
                +fact {
                    name = "link"
                    arguments {
                        +fact {
                            name = "1"
                        }
                        +fact {
                            name = "3"
                        }
                    }
                }
                +fact {
                    name = "link"
                    arguments {
                        +fact {
                            name = "3"
                        }
                        +fact {
                            name = "4"
                        }
                    }
                }
                +rule {
                    name = "path"
                    arguments {
                        +x0
                        +y0
                        +fact {
                            name = "c"
                            arguments {
                                +x0
                                +fact {
                                    name = "c"
                                    arguments {
                                        +y0
                                        +fact {
                                            name = "nil"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    body = fact {
                        name = "link"
                        arguments {
                            +x0
                            +y0
                        }
                    }
                }
                +rule {
                    name = "path"
                    arguments {
                        +x0
                        +y0
                        +fact {
                            name = "c"
                            arguments {
                                +x0
                                +w0
                            }
                        }
                    }
                    body =
                        fact {
                            name = "link"
                            arguments {
                                +x0
                                +z0
                            }
                        } and
                            fact {
                                name = "path"
                                arguments {
                                    +z0
                                    +y0
                                    +w0
                                }
                            }
                }
            }
        }

        val literals0 = kb0.literals
        val predicates0 = kb0.predicates

        val x1: Term = Term.Var("x")
        val y1: Term = Term.Var("y")
        val z1: Term = Term.Var("z")
        val w1: Term = Term.Var("w")
        val kb1 =
            KnowledgeBase(
                listOf(
                    Term.Fact("link", "0".asTerm, "1".asTerm),
                    Term.Fact("link", "1".asTerm, "2".asTerm),
                    Term.Fact("link", "2".asTerm, "4".asTerm),
                    Term.Fact("link", "1".asTerm, "3".asTerm),
                    Term.Fact("link", "3".asTerm, "4".asTerm),
                    Term.Rule(
                        "path",
                        x1,
                        y1,
                        Term.Fact("c", x1, Term.Fact("c", y1, "nil".asTerm)),
                    ) {
                        Term.Fact("link", x1, y1)
                    },
                    Term.Rule("path", x1, y1, Term.Fact("c", x1, w1)) {
                        Term.Fact("link", x1, z1) and Term.Fact("path", z1, y1, w1)
                    },
                )
            )

        val literals1 = kb1.literals
        val predicates1 = kb1.predicates

        assertEquals(literals0, literals1)
        assertEquals(predicates0, predicates1)
    }
}
