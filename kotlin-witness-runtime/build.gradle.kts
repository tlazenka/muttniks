plugins {
    kotlin("multiplatform")
    `maven-publish`
}

kotlin {
    jvm()
    js(IR) {
        browser()
    }
    sourceSets {
        commonMain.dependencies {
            implementation(project(":witness-annotations"))
        }
    }
}

publishing {
    publications.withType<MavenPublication>().configureEach {
        groupId = "com.stateblaster.witness"
        artifactId = "witness-runtime"
        version = "0.1.0"
    }
}
