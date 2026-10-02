plugins {
    kotlin("jvm")
    `maven-publish`
}

group = "com.muttniks"

version = "0.1.0-SNAPSHOT"

kotlin { jvmToolchain(21) }

dependencies {
    implementation(project(":tacky"))
    testImplementation(kotlin("test"))
}

tasks.test { useJUnitPlatform() }

publishing {
    publications {
        create<MavenPublication>("mavenJava") {
            from(components["java"])
            artifactId = "like-rules"
        }
    }
    repositories {
        maven {
            name = "embedded"
            url = uri(rootProject.layout.buildDirectory.dir("repo"))
        }
    }
}
