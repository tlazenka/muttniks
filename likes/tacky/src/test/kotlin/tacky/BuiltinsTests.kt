package tacky

import kotlin.test.*

class BuiltinsTests {

    @Test
    fun testCount() {
        val kb = KnowledgeBase(knowledge = List.countAxioms)
        val query: Term
        var binding: BindingMap? = null

        val list = List.from(elements = listOf("1".asTerm, "2".asTerm, "3".asTerm))
        query = List.count(list = list, count = Term.Var("?"))
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(3))
    }

    @Test
    fun testContains() {
        val kb = KnowledgeBase(knowledge = List.containsAxioms)
        var query: Term
        var binding: BindingMap? = null

        val list = List.from(elements = listOf("1".asTerm, "2".asTerm, "3".asTerm))
        query = List.contains(list = list, element = "0".asTerm)
        assertFalse(kb.ask(query).hasNext())
        query = List.contains(list = list, element = "1".asTerm)
        binding = kb.ask(query).next()
        assertNotNull(binding)
        query = List.contains(list = list, element = "2".asTerm)
        binding = kb.ask(query).next()
        assertNotNull(binding)
        query = List.contains(list = list, element = "3".asTerm)
        binding = kb.ask(query).next()
        assertNotNull(binding)
    }

    @Test
    fun testConcat() {
        val kb = KnowledgeBase(knowledge = List.concatAxioms)
        val query: Term
        var binding: BindingMap? = null

        val list1 = List.from(elements = listOf("1".asTerm, "2".asTerm, "3".asTerm))
        val list2 = List.from(elements = listOf("4".asTerm, "5".asTerm, "6".asTerm))
        query = List.concat(list1, list2, Term.Var("?"))
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(
            binding["?"],
            List.from(
                elements =
                    listOf("1".asTerm, "2".asTerm, "3".asTerm, "4".asTerm, "5".asTerm, "6".asTerm)
            ),
        )
    }

    @Test
    fun testGreater() {
        val kb = KnowledgeBase(knowledge = Nat.relationAxioms)
        var query: Term

        query = Nat.greater(Nat.from(2), Nat.from(2))
        // 2 > 2
        assertTrue(kb.ask(query).toList().isEmpty())
        query = Nat.greater(Nat.from(5), Nat.from(2))
        // 5 > 2
        assertEquals(kb.ask(query).toList().size, 1)
        query = Nat.greater(Nat.from(2), Nat.from(5))
        // 2 > 5
        assertTrue(kb.ask(query).toList().isEmpty())
    }

    @Test
    fun testGreaterOrEqual() {
        val kb = KnowledgeBase(knowledge = Nat.relationAxioms)
        var query: Term

        query = Nat.greaterOrEqual(Nat.from(2), Nat.from(2))
        // 2 >= 2
        assertEquals(kb.ask(query).toList().size, 1)
        query = Nat.greaterOrEqual(Nat.from(5), Nat.from(2))
        // 5 >= 2
        assertEquals(kb.ask(query).toList().size, 1)
        query = Nat.greaterOrEqual(Nat.from(2), Nat.from(5))
        // 2 >= 5
        assertTrue(kb.ask(query).toList().isEmpty())
    }

    @Test
    fun testSmaller() {
        val kb = KnowledgeBase(knowledge = Nat.relationAxioms)
        var query: Term

        query = Nat.smaller(Nat.from(2), Nat.from(2))
        // 2 < 2
        assertTrue(kb.ask(query).toList().isEmpty())
        query = Nat.smaller(Nat.from(5), Nat.from(2))
        // 5 < 2
        assertTrue(kb.ask(query).toList().isEmpty())
        query = Nat.smaller(Nat.from(2), Nat.from(5))
        // 2 < 5
        assertEquals(kb.ask(query).toList().size, 1)
    }

    @Test
    fun testSmallerOrEqual() {
        val kb = KnowledgeBase(knowledge = Nat.relationAxioms)
        var query: Term

        query = Nat.smallerOrEqual(Nat.from(2), Nat.from(2))
        // 2 <= 2
        assertEquals(kb.ask(query).toList().size, 1)
        query = Nat.smallerOrEqual(Nat.from(5), Nat.from(2))
        // 5 <= 2
        assertTrue(kb.ask(query).toList().isEmpty())
        query = Nat.smallerOrEqual(Nat.from(2), Nat.from(5))
        // 2 <= 5
        assertEquals(kb.ask(query).toList().size, 1)
    }

    @Test
    fun testAdd() {
        val kb = KnowledgeBase(knowledge = Nat.arithmeticAxioms)
        val res = Term.Var("?")
        var query: Term
        var binding: BindingMap? = null

        query = Nat.add(Nat.from(2), Nat.from(5), res)
        // 2 + 5 = ?
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(7))
        query = Nat.add(Nat.from(2), res, Nat.from(7))
        // 2 + ? = 7
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(5))
        query = Nat.add(res, Nat.from(5), Nat.from(7))
        // ? + 5 = 7
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(2))
    }

    @Test
    fun testSub() {
        val kb = KnowledgeBase(knowledge = Nat.arithmeticAxioms)
        val res = Term.Var("?")
        var query: Term
        var binding: BindingMap?

        query = Nat.sub(Nat.from(2), Nat.from(5), res)
        // 2 - 5 = ?
        assertFalse(kb.ask(query).hasNext())
        query = Nat.sub(Nat.from(5), Nat.from(2), res)
        // 5 - 2 = ?
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(3))
        query = Nat.sub(Nat.from(5), res, Nat.from(3))
        // 5 - ? = 3
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(2))
        query = Nat.sub(res, Nat.from(2), Nat.from(3))
        // ? - 2 = 3
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(5))
    }

    @Test
    fun testMul() {
        val kb = KnowledgeBase(knowledge = Nat.arithmeticAxioms)
        val res = Term.Var("?")
        var query: Term
        var binding: BindingMap?

        query = Nat.mul(Nat.from(5), Nat.from(2), res)
        // 5 * 2 = ?
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(10))
        query = Nat.mul(Nat.from(5), res, Nat.from(10))
        // 5 * ? = 10
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(2))
        query = Nat.mul(res, Nat.from(2), Nat.from(10))
        // ? * 2 = 10
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(5))
    }

    @Test
    fun testDiv() {
        val kb = KnowledgeBase(knowledge = Nat.arithmeticAxioms)
        val res = Term.Var("?")
        var query: Term
        var binding: BindingMap?

        query = Nat.div(Nat.from(2), Nat.from(0), res)
        // 2 / 0 = ?
        assertFalse(kb.ask(query).hasNext())
        query = Nat.div(Nat.from(2), Nat.from(6), res)
        // 2 / 6 = ?
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.zero)
        query = Nat.div(Nat.from(6), Nat.from(2), res)
        // 6 / 2 = ?
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(3))
        query = Nat.div(Nat.from(6), res, Nat.from(3))
        // 6 / ? = 3
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(2))
        query = Nat.div(res, Nat.from(2), Nat.from(3))
        // ? / 2 = 3
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(6))
        query = Nat.div(res, Nat.from(3), Nat.from(2))
        // ? / 3 = 2
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(6))
    }

    @Test
    fun testMod() {
        val kb = KnowledgeBase(knowledge = Nat.arithmeticAxioms)
        val res = Term.Var("?")
        var query: Term
        var binding: BindingMap?

        query = Nat.mod(Nat.from(2), Nat.from(0), res)
        // 2 % 0 = ?
        assertFalse(kb.ask(query).hasNext())
        query = Nat.mod(Nat.from(2), Nat.from(6), res)
        // 2 % 6 = ?
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(2))
        query = Nat.mod(Nat.from(6), Nat.from(2), res)
        // 6 % 2 = ?
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.zero)
        query = Nat.mod(Nat.from(6), Nat.from(4), res)
        // 6 % 4 = ?
        binding = kb.ask(query).next()
        assertNotNull(binding)
        assertEquals(binding["?"], Nat.from(2))
    }

    @Test
    fun testAsKotlinInt() {
        assertEquals(Nat.asKotlinInt(Nat.from(5)), 5)
        assertNull(Nat.asKotlinInt(Nat.succ(Term.Var("?"))))
    }
}
