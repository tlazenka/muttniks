package tacky

object Nat {

    // MARK: Generators

    val zero: Term = Term.Lit("nat::0")

    fun succ(n: Term): Term {
        if (!(isNat(n))) {
            throw AssertionError("'${n}' is not a builtin natural number")
        }
        return Term.Fact("nat::succ", n)
    }

    // MARK: Predicates

    fun greater(lhs: Term, rhs: Term): Term {
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(rhs))) {
            throw AssertionError("'${rhs}' is not a builtin natural number")
        }
        return Term.Fact("nat::>", lhs, rhs)
    }

    fun greaterOrEqual(lhs: Term, rhs: Term): Term {
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(rhs))) {
            throw AssertionError("'${rhs}' is not a builtin natural number")
        }
        return Term.Fact("nat::>=", lhs, rhs)
    }

    fun smaller(lhs: Term, rhs: Term): Term {
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(rhs))) {
            throw AssertionError("'${rhs}' is not a builtin natural number")
        }
        return Term.Fact("nat::<", lhs, rhs)
    }

    fun smallerOrEqual(lhs: Term, rhs: Term): Term {
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(rhs))) {
            throw AssertionError("'${rhs}' is not a builtin natural number")
        }
        return Term.Fact("nat::<=", lhs, rhs)
    }

    fun add(lhs: Term, rhs: Term, res: Term): Term {
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(res))) {
            throw AssertionError("'${res}' is not a builtin natural number")
        }
        return Term.Fact("nat::+", lhs, rhs, res)
    }

    fun sub(lhs: Term, rhs: Term, res: Term): Term {
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(res))) {
            throw AssertionError("'${res}' is not a builtin natural number")
        }
        return Term.Fact("nat::-", lhs, rhs, res)
    }

    fun mul(lhs: Term, rhs: Term, res: Term): Term {
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(res))) {
            throw AssertionError("'${res}' is not a builtin natural number")
        }
        return Term.Fact("nat::*", lhs, rhs, res)
    }

    fun div(lhs: Term, rhs: Term, res: Term): Term {
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(res))) {
            throw AssertionError("'${res}' is not a builtin natural number")
        }
        return Term.Fact("nat::/", lhs, rhs, res)
    }

    fun mod(lhs: Term, rhs: Term, res: Term): Term {
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin natural number")
        }
        if (!(isNat(res))) {
            throw AssertionError("'${res}' is not a builtin natural number")
        }
        return Term.Fact("nat::%", lhs, rhs, res)
    }

    // MARK: Axioms

    val axioms: kotlin.collections.List<Term>
        get() = arithmeticAxioms

    val relationAxioms: kotlin.collections.List<Term> =
        {
            val x: Term = Term.Var("x")
            val y: Term = Term.Var("y")
            listOf(
                Term.Fact("nat::>", succ(x), zero),
                Term.Rule("nat::>", succ(x), succ(y)) {
                    greater(x, y)
                },
                Term.Fact("nat::>=", x, x),
                Term.Rule("nat::>=", x, y) {
                    greater(x, y)
                },
                Term.Fact("nat::<", zero, succ(x)),
                Term.Rule("nat::<", succ(x), succ(y)) {
                    smaller(x, y)
                },
                Term.Fact("nat::<=", x, x),
                Term.Rule("nat::<=", x, y) {
                    smaller(x, y)
                },
            )
        }()

    val arithmeticAxioms: kotlin.collections.List<Term> =
        {
            val v: Term = Term.Var("v")
            val w: Term = Term.Var("w")
            val x: Term = Term.Var("x")
            val y: Term = Term.Var("y")
            val z: Term = Term.Var("z")
            relationAxioms +
                listOf(
                    Term.Fact("nat::+", zero, y, y),
                    Term.Rule("nat::+", succ(x), y, z) {
                        add(x, succ(y), z)
                    },
                    Term.Fact("nat::-", x, zero, x),
                    Term.Rule("nat::-", succ(x), succ(y), z) {
                        sub(x, y, z)
                    },
                    Term.Fact("nat::*", zero, y, zero),
                    Term.Rule("nat::*", succ(x), y, z) {
                        mul(x, y, w) and add(w, y, z)
                    },
                    Term.Rule("nat::/", x, y, zero) {
                        smaller(x, y)
                    },
                    Term.Rule("nat::/", x, succ(y), succ(z)) {
                        sub(x, succ(y), w) and div(w, succ(y), z)
                    },
                    Term.Rule("nat::%", x, succ(y), z) {
                        div(x, succ(y), w) and mul(succ(y), w, v) and sub(x, v, z)
                    },
                )
        }()

    // MARK: Helpers

    fun from(i: Int): Term = if (i > 0) succ(from(i - 1)) else zero

    fun asKotlinInt(t: Term): Int? {
        return when {
            t == zero -> 0
            (t is Term.TermInternal) && (t.name == "nat::succ") -> {
                val n = asKotlinInt(t.arguments.firstOrNull()!!)
                when {
                    n != null -> n + 1
                    else -> null
                }
            }
            else -> null
        }
    }

    fun isNat(t: Term): Boolean {
        return when {
            (t is Term.Var) || (t == zero) -> true
            (t is Term.TermInternal) && (t.name == "nat::succ") ->
                t.arguments.size == 1 && isNat(t.arguments[0])
            else -> false
        }
    }
}

object List {

    // MARK: Generators

    val empty: Term = Term.Lit("list::empty")

    fun cons(head: Term, tail: Term): Term {
        if (!isList(tail)) {
            throw IllegalArgumentException("'${tail}' is not a list")
        }
        return Term.Fact("list::cons", head, tail)
    }

    // MARK: Predicates

    fun count(list: Term, count: Term): Term {
        if (!(isList(list))) {
            throw AssertionError("'${list}' is not a builtin list")
        }
        return Term.Fact("list::count", list, count)
    }

    fun contains(list: Term, element: Term): Term {
        if (!(isList(list))) {
            throw AssertionError("'${list}' is not a builtin list")
        }
        return Term.Fact("list::contains", list, element)
    }

    fun concat(lhs: Term, rhs: Term, res: Term): Term {
        if (!(isList(lhs))) {
            throw AssertionError("'${lhs}' is not a builtin list")
        }
        if (!(isList(rhs))) {
            throw AssertionError("'${rhs}' is not a builtin list")
        }
        if (!(isList(res))) {
            throw AssertionError("'${res}' is not a builtin list")
        }
        return Term.Fact("list::concat", lhs, rhs, res)
    }

    // MARK: Axioms

    val axioms: kotlin.collections.List<Term>
        get() = countAxioms + containsAxioms + concatAxioms

    val countAxioms: kotlin.collections.List<Term> =
        {
            val a: Term = Term.Var("a")
            val b: Term = Term.Var("b")
            val c: Term = Term.Var("c")
            listOf(
                Term.Fact("list::count", empty, Nat.zero),
                Term.Rule("list::count", cons(a, b), Nat.succ(c)) {
                    Term.Fact("list::count", b, c)
                },
            )
        }()

    val containsAxioms: kotlin.collections.List<Term> =
        {
            val a: Term = Term.Var("a")
            val b: Term = Term.Var("b")
            val c: Term = Term.Var("c")
            listOf(
                Term.Fact("list::contains", cons(a, b), a),
                Term.Rule("list::contains", cons(a, b), c) {
                    Term.Fact("list::contains", b, c)
                },
            )
        }()

    val concatAxioms: kotlin.collections.List<Term> =
        {
            val a: Term = Term.Var("a")
            val b: Term = Term.Var("b")
            val c: Term = Term.Var("c")
            val d: Term = Term.Var("d")
            listOf(
                Term.Fact("list::concat", empty, a, a),
                Term.Fact("list::concat", a, empty, a),
                Term.Rule("list::concat", cons(a, b), c, cons(a, d)) {
                    Term.Fact("list::concat", b, c, d)
                },
            )
        }()

    // MARK: Helpers

    fun from(elements: Collection<Term>): Term =
        if (!elements.isEmpty()) cons(elements.firstOrNull()!!, from(elements = elements.drop(1)))
        else empty

    fun isList(t: Term): Boolean {
        return when {
            (t is Term.Var) || (t == empty) -> true
            (t is Term.TermInternal) && (t.name == "list::cons") ->
                t.arguments.size == 2 && isList(t.arguments[1])
            else -> false
        }
    }
}
