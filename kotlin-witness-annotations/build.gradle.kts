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
        commonMain.dependencies {}
    }
}

publishing {
    publications.withType<MavenPublication>().configureEach {
        groupId = "com.stateblaster.witness"
        artifactId = "witness-annotations"
        version = "0.1.0"
    }
}
