package tacky

data class AnswerSet(private val realizer: RealizerBase, private val variables: Set<String>) :
    SourcedIterator<Map<String, Term>> {
    override fun poll(): Map<String, Term>? =
        realizer.poll()?.reified?.filter { variables.contains(it.key) }

    override var nextElement: Map<String, Term>? = null
}

internal fun AnswerSet.toList(): kotlin.collections.List<Map<String, Term>> {
    return this.iterator().asSequence().toList()
}
