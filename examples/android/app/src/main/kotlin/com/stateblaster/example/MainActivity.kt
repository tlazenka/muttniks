package com.stateblaster.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.serialization.kotlinx.json.json
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                OnboardingApp()
            }
        }
    }
}

@Composable
private fun OnboardingApp() {
    val machine = remember {
        OnboardingMachine.initialState()
    }
    val _json = remember {
        kotlinx.serialization.json.Json {
            classDiscriminator = "type"
        }
    }
    val http =
        remember(_json) {
            HttpClient(OkHttp) {
                install(ContentNegotiation) {
                    json(_json)
                }
            }
        }
    DisposableEffect(http) {
        onDispose {
            http.close()
        }
    }
    val client =
        remember(http, _json) {
            OnboardingClient(
                http,
                "http://10.0.2.2:8080",
                _json,
            )
        }
    OnboardingNavigation(
        machine,
        OnboardingScreens(
            phoneEntry = { scope -> PhoneScreen(scope, client) },
            codeEntry = { scope -> CodeScreen(scope, client) },
            phoneError = { scope ->
                ErrorScreen(scope.state.error)
            },
            codeError = { scope ->
                ErrorScreen(scope.state.error)
            },
            finished = { FinishedScreen() },
        ),
    )
}

@Composable
private fun PhoneScreen(
    scope: PhoneEntryScope,
    client: OnboardingClient,
) {
    var phone by remember { mutableStateOf("") }
    var submitting by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()

    ScreenColumn {
        Text("Phone Number", style = MaterialTheme.typography.headlineMedium)
        OutlinedTextField(
            phone,
            { phone = it },
            label = { Text("Phone Number") },
            modifier = Modifier.fillMaxWidth(),
            enabled = !submitting,
        )
        Button(
            onClick = {
                coroutineScope.launch {
                    submitting = true
                    try {
                        client
                            .submitPhone(
                                SubmitPhone(phone),
                            )
                            .applyTo(scope)
                    } finally {
                        submitting = false
                    }
                }
            },
            enabled = !submitting,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (submitting) "Loading..." else "Send Code")
        }
    }
}

@Composable
private fun CodeScreen(
    scope: CodeEntryScope,
    client: OnboardingClient,
) {
    var code by remember { mutableStateOf(scope.state.code) }
    var submitting by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()

    ScreenColumn {
        Text("Verification Code", style = MaterialTheme.typography.headlineMedium)
        Text(scope.state.phoneNumber)
        OutlinedTextField(
            code,
            { code = it },
            label = { Text("Verification Code") },
            modifier = Modifier.fillMaxWidth(),
            enabled = !submitting,
        )
        Button(
            onClick = {
                coroutineScope.launch {
                    submitting = true
                    try {
                        client
                            .submitCode(
                                SubmitCode(
                                    phoneNumber = scope.state.phoneNumber,
                                    code = code,
                                ),
                            )
                            .applyTo(scope)
                    } finally {
                        submitting = false
                    }
                }
            },
            enabled = !submitting,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (submitting) "Loading..." else "Sign In")
        }
    }
}

@Composable
private fun ErrorScreen(message: String) {
    ScreenColumn {
        Text("Sorry, there was an error.", style = MaterialTheme.typography.headlineMedium)
        Text(message)
        Text("Tap, press, or click Back to go back")
    }
}

@Composable
private fun FinishedScreen() {
    ScreenColumn {
        Text("Congratulations!", style = MaterialTheme.typography.headlineLarge)
        Text("Consider yourself onboarded.")
    }
}

@Composable
private fun ScreenColumn(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Spacer(Modifier.height(24.dp))
        content()
    }
}
