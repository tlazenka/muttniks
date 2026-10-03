package tacky

import kotlin.test.*

class CollectionExtensionsTests {

    fun newSourcedIterator(): SourcedIterator<Int> =
        object : SourcedIterator<Int> {
            val list = arrayOf(1, 2, 3)
            var currentIndex = 0
            override var nextElement: Int? = null

            override fun poll(): Int? {
                val result = list.getOrNull(currentIndex)
                currentIndex++
                return result
            }
        }

    @Test
    fun testSourcedIterator() {
        val sourcedIterator = newSourcedIterator()

        assertTrue(sourcedIterator.hasNext())
        assertEquals(sourcedIterator.next(), 1)
        assertTrue(sourcedIterator.hasNext())
        assertTrue(sourcedIterator.hasNext())
        assertTrue(sourcedIterator.hasNext())
        assertEquals(sourcedIterator.next(), 2)
        assertEquals(sourcedIterator.next(), 3)
        assertFalse(sourcedIterator.hasNext())
        assertFalse(sourcedIterator.hasNext())
    }

    @Test
    fun testSourcedIteratorIteration() {

        val sourcedIterator0 = newSourcedIterator()
        val result0 = mutableListOf<Int>()
        for (i in sourcedIterator0) {
            result0.add(i)
        }
        assertTrue(result0.toTypedArray().contentEquals(arrayOf(1, 2, 3)))

        val sourcedIterator1 = newSourcedIterator()
        val result1 = sourcedIterator1.asSequence().toList()
        assertTrue(result1.toTypedArray().contentEquals(arrayOf(1, 2, 3)))
    }
}
