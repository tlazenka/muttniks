pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "state-blaster"

include(":witness-annotations", ":witness-runtime", ":witness-processor")

project(":witness-annotations").projectDir = file("kotlin-witness-annotations")

project(":witness-runtime").projectDir = file("kotlin-witness-runtime")

project(":witness-processor").projectDir = file("kotlin-witness-processor")
