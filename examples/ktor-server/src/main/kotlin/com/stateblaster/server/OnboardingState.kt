package com.stateblaster.server

import com.stateblaster.witness.*
import kotlinx.serialization.Serializable

@Serializable data class SubmitPhone(val phoneNumber: String)

@Serializable data class SubmitCode(val phoneNumber: String, val code: String)

@StateGraph
@KtorService("/onboarding")
@KtorServer
sealed interface OnboardingState {
    @Initial
    @Operation("submitPhone", SubmitPhone::class)
    @Transition(CodeEntry::class)
    @Transition(PhoneError::class)
    data object PhoneEntry : OnboardingState

    @Operation("submitCode", SubmitCode::class)
    @Transition(Finished::class)
    @Transition(CodeError::class)
    data class CodeEntry(val phoneNumber: String, val code: String) : OnboardingState

    @Transition(PhoneEntry::class)
    data class PhoneError(val phoneNumber: String, val error: String) : OnboardingState

    @Transition(CodeEntry::class)
    data class CodeError(val phoneNumber: String, val code: String, val error: String) :
        OnboardingState

    data object Finished : OnboardingState
}
