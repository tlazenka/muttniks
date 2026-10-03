/*
 * Copyright 2018 Juan Ignacio Saravia
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * This file was modified from the original.
 */

package tacky

import kotlin.collections.List
import kotlin.properties.Delegates

@DslMarker annotation class TermDslMarker

fun conjunction(block: ConjunctionDslBuilder.() -> Unit): Term.Conjunction =
    ConjunctionDslBuilder().apply(block).build()

@TermDslMarker
class ConjunctionDslBuilder() {
    var lhs: Term by Delegates.notNull()

    var rhs: Term by Delegates.notNull()

    fun withLhs(lhs: Term): ConjunctionDslBuilder = this.apply { this.lhs = lhs }

    fun withRhs(rhs: Term): ConjunctionDslBuilder = this.apply { this.rhs = rhs }

    fun build(): Term.Conjunction = Term.Conjunction(lhs, rhs)
}

fun disjunction(block: DisjunctionDslBuilder.() -> Unit): Term.Disjunction =
    DisjunctionDslBuilder().apply(block).build()

@TermDslMarker
class DisjunctionDslBuilder() {
    var lhs: Term by Delegates.notNull()

    var rhs: Term by Delegates.notNull()

    fun withLhs(lhs: Term): DisjunctionDslBuilder = this.apply { this.lhs = lhs }

    fun withRhs(rhs: Term): DisjunctionDslBuilder = this.apply { this.rhs = rhs }

    fun build(): Term.Disjunction = Term.Disjunction(lhs, rhs)
}

internal fun ruleInternal(block: RuleInternalDslBuilder.() -> Unit): Term =
    RuleInternalDslBuilder().apply(block).build()

@TermDslMarker
class RuleInternalDslBuilder() {
    var name: String by Delegates.notNull()

    var arguments: kotlin.collections.List<Term> = listOf()

    var body: Term by Delegates.notNull()

    fun withName(name: String): RuleInternalDslBuilder = this.apply { this.name = name }

    fun arguments(block: ArgumentsDslCollection.() -> Unit): RuleInternalDslBuilder =
        this.apply {
            this.arguments = ArgumentsDslCollection().apply { block() }.argumentsDslCollection
        }

    fun withArguments(arguments: kotlin.collections.List<Term>): RuleInternalDslBuilder =
        this.apply { this.arguments = arguments }

    fun withBody(body: Term): RuleInternalDslBuilder = this.apply { this.body = body }

    fun build(): Term = Term.RuleInternal(name, arguments, body)

    class ArgumentsDslCollection internal constructor() {
        internal val argumentsDslCollection: ArrayList<Term> = ArrayList()

        operator fun Term.unaryPlus() {
            argumentsDslCollection.add(this)
        }
    }
}

internal fun termInternal(block: TermInternalDslBuilder.() -> Unit): Term =
    TermInternalDslBuilder().apply(block).build()

@TermDslMarker
class TermInternalDslBuilder() {
    var name: String by Delegates.notNull()

    var arguments: kotlin.collections.List<Term> = listOf()

    fun withName(name: String): TermInternalDslBuilder = this.apply { this.name = name }

    fun arguments(block: ArgumentsDslCollection.() -> Unit): TermInternalDslBuilder =
        this.apply {
            this.arguments = ArgumentsDslCollection().apply { block() }.argumentsDslCollection
        }

    fun withArguments(arguments: kotlin.collections.List<Term>): TermInternalDslBuilder =
        this.apply { this.arguments = arguments }

    fun build(): Term = Term.TermInternal(name, arguments)

    class ArgumentsDslCollection internal constructor() {
        internal val argumentsDslCollection: ArrayList<Term> = ArrayList()

        operator fun Term.unaryPlus() {
            argumentsDslCollection.add(this)
        }
    }
}

fun fact(block: TermInternalDslBuilder.() -> Unit): Term = termInternal(block)

fun rule(block: RuleInternalDslBuilder.() -> Unit): Term = ruleInternal(block)

fun lit(block: ValDslBuilder.() -> Unit): Term.Val = `val`(block)

fun `val`(block: ValDslBuilder.() -> Unit): Term.Val = ValDslBuilder().apply(block).build()

@TermDslMarker
class ValDslBuilder() {
    var value: Any by Delegates.notNull()

    fun withValue(value: Any): ValDslBuilder = this.apply { this.value = value }

    fun build(): Term.Val = Term.Val(value)
}

fun `var`(block: VarDslBuilder.() -> Unit): Term.Var = VarDslBuilder().apply(block).build()

@TermDslMarker
class VarDslBuilder() {
    var value: String by Delegates.notNull()

    fun withValue(value: String): VarDslBuilder = this.apply { this.value = value }

    fun build(): Term.Var = Term.Var(value)
}

fun knowledgeBase(block: KnowledgeBaseDslBuilder.() -> Unit): KnowledgeBase =
    KnowledgeBaseDslBuilder().apply(block).build()

@TermDslMarker
class KnowledgeBaseDslBuilder() {
    var knowledge: List<Term> by Delegates.notNull()

    fun knowledge(block: KnowledgeDslCollection.() -> Unit): KnowledgeBaseDslBuilder =
        this.apply {
            this.knowledge = KnowledgeDslCollection().apply { block() }.knowledgeDslCollection
        }

    fun withKnowledge(knowledge: List<Term>): KnowledgeBaseDslBuilder =
        this.apply { this.knowledge = knowledge }

    fun build(): KnowledgeBase = KnowledgeBase(knowledge)

    class KnowledgeDslCollection internal constructor() {
        internal val knowledgeDslCollection: ArrayList<Term> = ArrayList()

        operator fun Term.unaryPlus() {
            knowledgeDslCollection.add(this)
        }
    }
}
