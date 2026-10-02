package tacky

fun <S> Collection<S>.concatenated(other: Collection<S>) = SequenceConcatenation(this, other)

data class SequenceConcatenation<S>(
    private val first: Collection<S>,
    private val second: Collection<S>,
) : Iterator<S> {
    private var iter2: Iterator<S> = second.iterator()
    private var iter1: Iterator<S> = first.iterator()

    override fun hasNext(): Boolean {
        if (iter1.hasNext()) {
            return true
        }
        return iter2.hasNext()
    }

    override fun next(): S {
        if (iter1.hasNext()) {
            return iter1.next()
        }
        return iter2.next()
    }
}

interface SourcedIterator<T> : Iterator<T> {
    fun poll(): T?

    var nextElement: T?

    override fun hasNext(): Boolean {
        if (nextElement == null) {
            nextElement = poll()
        }
        return nextElement != null
    }

    override fun next(): T {
        if (!(hasNext())) {
            throw NoSuchElementException()
        }
        val result = nextElement
        nextElement = null
        return result!!
    }
}
