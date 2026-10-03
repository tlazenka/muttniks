plugins {
    kotlin("jvm")
    `maven-publish`
}

dependencies {
    implementation("com.google.devtools.ksp:symbol-processing-api:2.3.10")
    implementation(project(":witness-annotations"))
}

kotlin {
    jvmToolchain(17)
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
            groupId = "com.stateblaster.witness"
            artifactId = "witness-processor"
            version = "0.1.0"
        }
    }
}
