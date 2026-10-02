package tacky

sealed class Term {
    data class Var(val value: String) : Term()

    data class Val(val value: Any) : Term()

    internal data class TermInternal(
        val name: String,
        val arguments: kotlin.collections.List<Term>,
    ) : Term()

    internal data class RuleInternal(
        val name: String,
        val arguments: kotlin.collections.List<Term>,
        val body: Term,
    ) : Term()

    data class Conjunction(val lhs: Term, val rhs: Term) : Term()

    data class Disjunction(val lhs: Term, val rhs: Term) : Term()

    val dnf: Term
        get() {
            when (this) {
                is Conjunction -> {
                    when {
                        rhs is Disjunction -> {
                            val a = lhs
                            val b = rhs.lhs
                            val c = rhs.rhs
                            return (a and b) or (a and c)
                        }
                        lhs is Disjunction -> {
                            val a = lhs.lhs
                            val b = lhs.rhs
                            val c = rhs

                            return (a and c) or (b and c)
                        }
                    }
                }
                else -> Unit
            }
            return this
        }

    val goals: kotlin.collections.List<kotlin.collections.List<Term>>
        get() {
            when (val dnf = dnf) {
                is Conjunction -> {
                    val lhs = dnf.lhs
                    val rhs = dnf.rhs
                    if (!(((lhs.goals.size == 1) && (rhs.goals.size == 1)))) {
                        throw AssertionError()
                    }
                    return listOf(lhs.goals[0] + rhs.goals[0])
                }
                is Disjunction -> {
                    val lhs = dnf.lhs
                    val rhs = dnf.rhs
                    return lhs.goals + rhs.goals
                }
                else -> Unit
            }
            return listOf(listOf(this))
        }

    val variables: Set<String>
        get() {
            return when (this) {
                is Var -> setOf(value)
                is Val -> setOf()
                is TermInternal ->
                    arguments.map { it.variables }.fold(emptySet()) { i, j -> i.union(j) }
                is RuleInternal -> {
                    val subtermVariables =
                        arguments
                            .map { it.variables }
                            .fold(emptySet()) { i: Set<String>, j -> i.union(j) }
                    body.variables.union(subtermVariables)
                }
                is Conjunction -> {
                    lhs.variables.union(rhs.variables)
                }
                is Disjunction -> {
                    lhs.variables.union(rhs.variables)
                }
            }
        }

    fun renaming(variables: Set<String>): Term {
        return when {
            ((this is Var) && (variables.contains(value))) -> {
                Var(value + "'")
            }
            (this is Var) -> this
            (this is Val) -> this
            (this is TermInternal) ->
                TermInternal(name = name, arguments = arguments.map { it.renaming(variables) })
            (this is RuleInternal) ->
                RuleInternal(
                    name = name,
                    arguments = arguments.map { it.renaming(variables) },
                    body = body.renaming(variables),
                )
            (this is Conjunction) -> Conjunction(lhs.renaming(variables), rhs.renaming(variables))
            (this is Disjunction) -> Disjunction(lhs.renaming(variables), rhs.renaming(variables))
            else -> throw RuntimeException("Unexpected case: ${this}")
        }
    }

    fun <T : Any> lit(value: T): Term = Val(value)

    inline fun <reified T> extractValue(): T? =
        when {
            this !is Val -> null
            value !is T -> null
            else -> value
        }

    // ///
    object Fact {
        operator fun invoke(name: String, vararg arguments: Term): Term =
            TermInternal(name = name, arguments = arguments.toList())
    }

    object Rule {
        operator fun invoke(name: String, vararg arguments: Term, body: () -> Term): Term =
            RuleInternal(name = name, arguments = arguments.toList(), body = body())
    }

    object Lit {
        operator fun invoke(value: Any) = Val(value)
    }

    operator fun get(vararg terms: Term): Term {
        if ((this !is TermInternal) || (this.arguments.isNotEmpty())) {
            throw RuntimeException("Cannot coerce '$this' into a functor")
        }

        return TermInternal(name = name, arguments = terms.toList())
    }

    // ///

    infix fun implies(rhs: Term): Term {
        val lhs = this
        if (rhs !is TermInternal) {
            throw IllegalArgumentException("Cannot use '${this}' as a rule head.")
        }
        val name = rhs.name
        val args = rhs.arguments
        return RuleInternal(name = name, arguments = args, body = lhs)
    }

    infix fun rightTack(rhs: Term): Term {
        val lhs =
            this as? TermInternal ?: throw RuntimeException("Cannot use '${this}' as a rule head.")
        val name = lhs.name
        val args = lhs.arguments
        return RuleInternal(name = name, arguments = args, body = rhs)
    }

    // ///
    infix fun and(rhs: Term): Term = Conjunction(this, rhs)

    // ///
    infix fun or(rhs: Term): Term = Disjunction(this, rhs)

    // ///
    infix fun unification(rhs: Term): Term =
        TermInternal(name = "lk.~=~", arguments = listOf(this, rhs))

    override fun toString(): String {
        return when (this) {
            is Var -> "$${value}"
            is Val -> "${value}"
            is TermInternal ->
                if (arguments.isEmpty()) name
                else
                    "${name}[${arguments.joinToString(
                separator = ", ",
                transform = { "${it}" },
            )}]"
            is RuleInternal -> {
                val head =
                    if (arguments.isEmpty()) name
                    else
                        "${name}[${arguments.joinToString(
                    separator = ", ",
                    transform = { "${it}" },
                )}]"
                "(${head} ⊢ ${body})"
            }
            is Conjunction -> "(${lhs} ∧ ${rhs})"
            is Disjunction -> "(${lhs} ∨ ${rhs})"
        }
    }
}

val String.asTerm
    get() = Term.Fact(this)
