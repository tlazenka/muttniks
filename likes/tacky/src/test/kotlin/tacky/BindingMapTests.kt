package tacky

import kotlin.test.Test
import kotlin.test.assertEquals

class BindingMapTests {

    @Test
    fun testShallowWalk() {
        val bindingMap: BindingMap =
            mapOf(
                "w" to Term.Fact("a"),
                "x" to Term.Var("y"),
                "y" to Term.Var("z"),
                "z" to Term.Fact("t", Term.Var("w")),
            )
        assertEquals(bindingMap.shallowWalk(Term.Fact("u")), Term.Fact("u"))
        assertEquals(bindingMap.shallowWalk(Term.Var("z")), Term.Fact("t", Term.Var("w")))
        assertEquals(bindingMap.shallowWalk(Term.Var("y")), Term.Fact("t", Term.Var("w")))
        assertEquals(bindingMap.shallowWalk(Term.Var("x")), Term.Fact("t", Term.Var("w")))
    }

    @Test
    fun testDeepWalk() {
        val bindingMap: BindingMap =
            mapOf(
                "w" to Term.Fact("a"),
                "x" to Term.Var("y"),
                "y" to Term.Var("z"),
                "z" to Term.Fact("t", Term.Var("w")),
            )
        assertEquals(bindingMap.deepWalk(Term.Fact("u")), Term.Fact("u"))
        assertEquals(bindingMap.deepWalk(Term.Var("z")), Term.Fact("t", Term.Fact("a")))
        assertEquals(bindingMap.deepWalk(Term.Var("y")), Term.Fact("t", Term.Fact("a")))
        assertEquals(bindingMap.deepWalk(Term.Var("x")), Term.Fact("t", Term.Fact("a")))
    }

    @Test
    fun testReified() {
        val bindingMap: BindingMap =
            mapOf(
                "w" to Term.Fact("a"),
                "x" to Term.Var("y"),
                "y" to Term.Var("z"),
                "z" to Term.Fact("t", Term.Var("w")),
            )
        val reifiedMap = bindingMap.reified
        assertEquals(reifiedMap["w"], Term.Fact("a"))
        assertEquals(reifiedMap["x"], Term.Fact("t", Term.Fact("a")))
        assertEquals(reifiedMap["y"], Term.Fact("t", Term.Fact("a")))
        assertEquals(reifiedMap["z"], Term.Fact("t", Term.Fact("a")))
    }

    @Test
    fun testBinding() {
        val bindingMap: BindingMap = mapOf("x" to Term.Var("y"))
        assertEquals(bindingMap.binding("v", term = Term.Fact("b"))["v"], Term.Fact("b"))
        assertEquals(bindingMap.binding("x", term = Term.Fact("b"))["x"], Term.Fact("b"))
    }

    @Test
    fun testMerged() {
        val bindingMap: BindingMap = mapOf("x" to Term.Var("y"))
        assertEquals(bindingMap.merged(other = mapOf("y" to Term.Var("z")))["y"], Term.Var("z"))
        assertEquals(bindingMap.merged(other = mapOf("x" to Term.Var("z")))["x"], Term.Var("z"))
    }
}
