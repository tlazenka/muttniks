package tacky

typealias BindingMap = Map<String, Term>

val Map<String, Term>.reified: Map<String, Term>
    get() {
        val result: HashMap<String, Term> = hashMapOf()
        for ((name, term) in this) {
            result[name] = deepWalk(term)
        }
        return result
    }

fun Map<String, Term>.shallowWalk(term: Term): Term {
    return when (term) {
        is Term.Var -> this[term.value]?.let { shallowWalk(it) } ?: term
        else -> term
    }
}

fun Map<String, Term>.deepWalk(term: Term): Term {
    return when (val walked = shallowWalk(term)) {
        is Term.TermInternal ->
            Term.TermInternal(name = walked.name, arguments = walked.arguments.map(::deepWalk))
        is Term.Conjunction -> Term.Conjunction(deepWalk(walked.lhs), deepWalk(walked.rhs))
        is Term.Disjunction -> Term.Disjunction(deepWalk(walked.lhs), deepWalk(walked.rhs))
        else -> walked
    }
}

fun Map<String, Term>.binding(name: String, term: Term): BindingMap {
    val result = this.toMutableMap()
    result[name] = term
    return result
}

fun Map<String, Term>.merged(other: BindingMap): BindingMap {
    val result = this.toMutableMap()
    for ((name, term) in other) {
        result[name] = term
    }
    return result
}

operator fun Map<String, Term>.get(name: Term): Term? {
    if (name !is Term.Var) {
        throw IllegalArgumentException()
    }
    return this[name.value]
}
