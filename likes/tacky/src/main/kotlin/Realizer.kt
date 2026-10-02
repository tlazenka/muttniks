package tacky

// / Base class for realizers.
interface RealizerBase : SourcedIterator<Map<String, Term>>

// / Realizer that alternatively pulls results from multiple sub-realizers.
class RealizerAlternator(realizers: kotlin.collections.List<Realizer>) : RealizerBase {
    private var index = 0
    private var realizers = realizers.toMutableList()

    override fun poll(): Map<String, Term>? {
        while (realizers.isNotEmpty()) {
            val result = realizers[index].poll()
            if (result == null) {
                realizers.removeAt(index)
                if (realizers.isNotEmpty()) {
                    index %= realizers.size
                }
                continue
            }
            index = (index + 1) % realizers.size
            return result
        }
        return null
    }

    override var nextElement: Map<String, Term>? = null
}

// / Standard goal realizer.
class Realizer(
    // / The goals to realize.
    private val goals: kotlin.collections.List<Term>,
    // / The knowledge base.
    private val knowledge: KnowledgeBase,
    // / The bindings already  determined by the parent realizer.
    private val parentBindings: BindingMap = mapOf(),
    // / The optional logger, for debug purpose.
    private var logger: Logger? = null,
) : RealizerBase {

    // / An iterator on the knowledge clauses to check.
    private var clauseIterator: Iterator<Term> = emptyList<Term>().iterator()
    // / The subrealizer, if any.
    private var subRealizer: RealizerBase? = null

    init {
        // Identify which part of the knowledge base the realizer should explore.
        if (!(goals.isNotEmpty())) {
            throw AssertionError()
        }
        when (val goal = goals.firstOrNull()!!) {
            is Term.TermInternal ->
                clauseIterator =
                    knowledge.predicates[goal.name]?.iterator() ?: emptyList<Term>().iterator()
            is Term.RuleInternal ->
                clauseIterator =
                    knowledge.predicates[goal.name]?.iterator() ?: emptyList<Term>().iterator()
            else -> Unit // Preserve Tacky's original behavior for non-predicate goals.
        }
    }

    override fun poll(): Map<String, Term>? {
        // If we have a subrealizer running, pull its results first.
        val sub = subRealizer
        if (sub != null) {
            val result = sub.poll()
            if (result != null) {
                return result.merged(other = parentBindings)
            } else {
                logger?.didBacktrack()
                subRealizer = null
            }
        }
        val goal = goals.firstOrNull()!!
        logger?.willRealize(goal = goal)

        // Check for the built-in `~=~/2` predicate.
        if ((goal is Term.TermInternal) && (goal.name == "lk.~=~")) {
            val args = goal.arguments
            if (!(args.size == 2)) {
                throw AssertionError()
            }
            val nodeResult = unify(goal = args[0], fact = args[1])
            if (nodeResult != null) {
                if (goals.size > 1) {
                    val subGoals = goals.drop(1).map { nodeResult.deepWalk(it) }
                    subRealizer =
                        Realizer(
                            goals = subGoals,
                            knowledge = knowledge,
                            parentBindings = nodeResult,
                            logger = logger,
                        )
                    val branchResult = subRealizer!!.poll()
                    if (branchResult != null) {
                        return branchResult.merged(other = parentBindings)
                    }
                } else {
                    return nodeResult.merged(other = parentBindings)
                }
            }
        }

        // Look for the next root clause.
        for (clause in clauseIterator) {
            logger?.willAttempt(clause = clause)
            if ((goal is Term.Val) && (clause is Term.Val) && (goal.value == clause.value)) {
                if (goals.size > 1) {
                    val subGoals = goals.drop(1)
                    subRealizer = Realizer(goals = subGoals, knowledge = knowledge, logger = logger)
                    val branchResult = subRealizer!!.poll()
                    if (branchResult != null) {
                        return branchResult.merged(parentBindings)
                    }
                }
            } else if ((goal is Term.TermInternal) && (clause is Term.TermInternal)) {
                val nodeResult = unify(goal = goal, fact = clause)
                if (nodeResult != null) {
                    if (goals.size > 1) {
                        val subGoals = goals.drop(1).map { nodeResult.deepWalk(it) }
                        subRealizer =
                            Realizer(
                                goals = subGoals,
                                knowledge = knowledge,
                                parentBindings = nodeResult,
                                logger = logger,
                            )
                        val branchResult = subRealizer!!.poll()
                        if (branchResult != null) {
                            return branchResult.merged(parentBindings)
                        }
                    } else {
                        return nodeResult.merged(parentBindings)
                    }
                }
            } else if ((goal is Term.TermInternal) && (clause is Term.RuleInternal)) {
                val goalName = goal.name
                val ruleName = clause.name
                val ruleArgs = clause.arguments
                val ruleBody = clause.body
                if (!(goalName == ruleName)) {
                    throw AssertionError()
                }

                // First we try to unify the rule head with the goal.
                val head: Term = Term.TermInternal(name = goalName, arguments = ruleArgs)
                val nodeResult = unify(goal = goal, fact = head)
                if (nodeResult != null) {
                    val subGoals = goals.drop(1).map { nodeResult.deepWalk(it) }
                    val ruleGoals =
                        ruleBody.goals.map { it.map { nodeResult.deepWalk(it) } + subGoals }
                    if (!(ruleGoals.isNotEmpty())) {
                        throw AssertionError()
                    }

                    // We have to make sure bound knowledge variables are renamed in the
                    // sub-realizer's
                    // knowledge, otherwise they may collide with the ones we already bound. For
                    // instance,
                    // consider a recursive rule `p(q($x), $y) ⊢ p($x, q($y))` and a goal `p($z,
                    // 0)`. `$z`
                    // would get bound to `q($x)` and `$y` to `0` before we try satisfy `p($x,
                    // q(0))`. But
                    // if `$x` wasn't renamed, we'd be trying to unify `$x` with `q($x)` while
                    // recursing.
                    val subKnowledge = knowledge.renaming(clause.variables.toSet())
                    val subRealizers = ruleGoals.map {
                        Realizer(
                            goals = it,
                            knowledge = subKnowledge,
                            parentBindings = nodeResult,
                            logger = logger,
                        )
                    }
                    subRealizer =
                        if (subRealizers.size > 1) RealizerAlternator(realizers = subRealizers)
                        else subRealizers[0]
                    val branchResult = subRealizer!!.poll()
                    if (branchResult != null) {
                        // Note the `branchResult` already contains the bindings of `nodeResult`, as
                        // the these
                        // will have been merged by sub-realizer.
                        return branchResult.merged(parentBindings)
                    }
                }
            } else {
                break
            }
        }
        return null
    }

    override var nextElement: Map<String, Term>? = null

    fun unify(goal: Term, fact: Term, bindings: BindingMap = mapOf()): BindingMap? {
        // Shallow-walk the terms to unify.
        val lhs = bindings.shallowWalk(goal)
        val rhs = bindings.shallowWalk(fact)

        // Equal terms always unify.
        when {
            lhs == rhs -> return bindings
            lhs is Term.Var -> {
                val name = lhs.value
                return when {
                    bindings[name] == null -> bindings.binding(name, term = rhs)
                    bindings[name] == rhs -> bindings
                    else -> null
                }
            }
            rhs is Term.Var -> {
                val name = rhs.value
                return when {
                    bindings[name] == null -> bindings.binding(name, term = lhs)
                    bindings[name] == lhs -> bindings
                    else -> null
                }
            }
            (lhs is Term.Val) && (rhs is Term.Val) -> {
                val lvalue = lhs.value
                val rvalue = rhs.value
                return if (lvalue == rvalue) bindings else null
            }
            (lhs is Term.TermInternal) && (rhs is Term.TermInternal) && (lhs.name == rhs.name) -> {
                val largs = lhs.arguments
                val rargs = rhs.arguments

                // Make sure both terms are of same arity.
                when {
                    largs.size != rargs.size -> return null

                    // Try unify subterms (i.e. arguments).

                    // Unification succeeded.
                    else -> {
                        var intermediateResult = bindings
                        for ((larg, rarg) in largs zip rargs) {
                            val b = unify(goal = larg, fact = rarg, bindings = intermediateResult)
                            if (b != null) {
                                intermediateResult = b
                            } else {
                                return null
                            }
                        }

                        // Unification succeeded.
                        return intermediateResult
                    }
                }
            }
            else -> return null
        }
    }
}
