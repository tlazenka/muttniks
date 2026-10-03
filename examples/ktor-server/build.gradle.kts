plugins {
    kotlin("jvm") version "2.3.20"
    kotlin("plugin.serialization") version "2.3.20"
    id("com.google.devtools.ksp") version "2.3.10"
    application
}

dependencies {
    runtimeOnly("ch.qos.logback:logback-classic:1.5.18")
    ksp("com.stateblaster.witness:witness-processor:0.1.0")
    implementation("com.stateblaster.witness:witness-annotations:0.1.0")
    implementation("io.ktor:ktor-server-netty:3.3.0")
    implementation("io.ktor:ktor-server-content-negotiation:3.3.0")
    implementation("io.ktor:ktor-server-call-logging:3.3.0")
    implementation("io.ktor:ktor-serialization-kotlinx-json:3.3.0")
}

application {
    mainClass.set("com.stateblaster.server.MainKt")
}

kotlin {
    jvmToolchain(17)
}
