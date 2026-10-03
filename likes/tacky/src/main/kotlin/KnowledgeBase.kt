package tacky

class KnowledgeBase : Iterator<Term> {
    // / The list of predicates in the knowledge base, grouped by functor.
    var predicates: HashMap<String, MutableList<Term>> = hashMapOf()
        private set

    // / The list of isolated literals in the knowledge base.
    var literals: MutableSet<Term> = hashSetOf()
        private set

    constructor(predicates: HashMap<String, MutableList<Term>>, literals: MutableSet<Term>) {
        val terms = predicates.values.flatten().concatenated(other = literals)
        for (term in terms) {
            if (term is Term.TermInternal) {
                continue
            }
            if (term is Term.RuleInternal) {
                continue
            }
            throw RuntimeException("Cannot use '${term}' as a predicate.")
        }
        this.predicates = predicates
        this.literals = literals
    }

    constructor(knowledge: kotlin.collections.List<Term>) {
        // / Extract predicates and literals from the given list of terms.
        for (term in knowledge) {
            when {
                term is Term.TermInternal -> {
                    val name = term.name
                    val group = predicates[name] ?: mutableListOf()
                    predicates[name] = (group + mutableListOf(term)).toMutableList()
                }
                term is Term.RuleInternal -> {
                    val name = term.name

                    val group = predicates[name] ?: mutableListOf()
                    predicates[name] = (group + listOf(term)).toMutableList()
                }
                term is Term.Val -> literals.add(term)
                (term is Term.Val) || (term is Term.Conjunction) || (term is Term.Disjunction) ->
                    throw RuntimeException("Cannot use '${term}' as a predicate.")
            }
        }
    }

    constructor(vararg terms: Term) : this(terms.asList())

    val iterator: Iterator<Term> by lazy {
        predicates.values.flatten().concatenated(literals).iterator()
    }

    override fun hasNext(): Boolean = iterator.hasNext()

    override fun next(): Term = iterator.next()

    // / The number of predicates and literals in the knowledge base.
    val count: Int
        get() = predicates.values.fold(0) { i, j -> i + j.size } + literals.size

    fun ask(query: Term, logger: Logger? = null): AnswerSet {
        when {
            (query is Term.Var) || (query is Term.RuleInternal) ->
                throw IllegalArgumentException("invalid query")
            else -> {
                // Build an array of realizers for each conjunction of goals in the query.
                val realizers =
                    query.goals.map {
                        Realizer(goals = it, knowledge = renaming(query.variables), logger = logger)
                    }
                // Return the goal realizer(s).
                if (!(realizers.isNotEmpty())) {
                    throw AssertionError()
                }
                val iterator =
                    if (realizers.size > 1) RealizerAlternator(realizers = realizers)
                    else realizers[0]
                return AnswerSet(realizer = iterator, variables = query.variables)
            }
        }
    }

    fun renaming(variables: Set<String>): KnowledgeBase {
        val result = KnowledgeBase(knowledge = listOf())
        for ((name, terms) in predicates) {
            result.predicates[name] = terms.map { it.renaming(variables) }.toMutableList()
        }
        result.literals = literals
        return result
    }

    fun renameVariables(term: Term): Term {
        return when (term) {
            is Term.Var -> {
                val name = term.value
                Term.Var(name + "'")
            }
            is Term.TermInternal ->
                Term.TermInternal(
                    name = term.name,
                    arguments = term.arguments.map(::renameVariables),
                )
            is Term.RuleInternal ->
                Term.RuleInternal(
                    name = term.name,
                    arguments = term.arguments.map(::renameVariables),
                    body = renameVariables(term = term.body),
                )
            is Term.Conjunction ->
                Term.Conjunction(renameVariables(term = term.lhs), renameVariables(term = term.rhs))
            is Term.Disjunction ->
                Term.Disjunction(renameVariables(term = term.lhs), renameVariables(term = term.rhs))
            else -> term
        }
    }

    operator fun plus(rhs: KnowledgeBase): KnowledgeBase {
        val lhs = this
        val result = KnowledgeBase(knowledge = listOf())
        for (name in lhs.predicates.keys.concatenated(other = rhs.predicates.keys)) {
            result.predicates[name] = lhs.predicates[name] ?: mutableListOf()
            val right = rhs.predicates[name]
            if (right != null) {
                val set = result.predicates[name]!!.toSet()
                result.predicates[name]?.addAll(right.filter { !set.contains(it) })
            }
        }
        result.literals = lhs.literals.union(rhs.literals).toMutableSet()
        return result
    }

    override fun toString(): String {
        return "[" + this.iterator.asSequence().map { "${it}" }.joinToString(separator = ", ") + "]"
    }
}
