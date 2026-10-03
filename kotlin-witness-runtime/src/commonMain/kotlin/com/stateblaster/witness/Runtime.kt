@file:OptIn(kotlin.concurrent.atomics.ExperimentalAtomicApi::class)

package com.stateblaster.witness

import kotlin.concurrent.atomics.AtomicReference
import kotlin.concurrent.atomics.ExperimentalAtomicApi

@LinearCapability
class Witness<S : Any>
internal constructor(
    internal val owner: StateOwner<S>,
)

@LinearCapability
class TransitionAuthority<S : Any, D : Any>
internal constructor(
    internal val source: S,
)

@OptIn(ExperimentalAtomicApi::class)
internal class StateOwner<S : Any>(initial: S) {
    private val value = AtomicReference<S?>(initial)

    val nonEmpty: Boolean
        get() = value.load() != null

    fun take(): S? {
        while (true) {
            val current = value.load() ?: return null
            if (value.compareAndSet(current, null)) return current
        }
    }
}

fun <S : Any> generatedWitness(state: S): Witness<S> = Witness(StateOwner(state))

fun <S : Any, D : Any> generatedAuthorize(
    witness: Witness<S>,
): TransitionAuthority<S, D>? {
    val source = witness.owner.take() ?: return null
    return TransitionAuthority(source)
}
