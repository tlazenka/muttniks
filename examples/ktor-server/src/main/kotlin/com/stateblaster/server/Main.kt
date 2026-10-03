package com.stateblaster.server

import io.ktor.serialization.kotlinx.json.*
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.plugins.calllogging.*
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.server.routing.*

private class RealOnboardingService : OnboardingService {
    override suspend fun submitPhone(request: SubmitPhone): SubmitPhoneResponse =
        if (request.phoneNumber.isBlank())
            SubmitPhoneResponse.PhoneError(request.phoneNumber, "We don't recognize this number.")
        else SubmitPhoneResponse.CodeEntry(request.phoneNumber, "")

    override suspend fun submitCode(request: SubmitCode): SubmitCodeResponse =
        if (request.code != "123456")
            SubmitCodeResponse.CodeError(
                request.phoneNumber,
                request.code,
                "Try 123456 (it always works).",
            )
        else SubmitCodeResponse.Finished
}

fun main() {
    embeddedServer(Netty, port = 8080) {
            install(ContentNegotiation) {
                json()
            }
            routing {
                onboardingRoutes(RealOnboardingService())
            }
        }
        .start(wait = true)
}
