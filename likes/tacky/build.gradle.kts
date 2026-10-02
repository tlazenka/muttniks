plugins {
    kotlin("jvm")
    `maven-publish`
}

group = "com.ticky"

version = "0.0.1-SNAPSHOT"

kotlin { jvmToolchain(21) }

dependencies {
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
}

publishing {
    publications {
        create<MavenPublication>("mavenJava") {
            from(components["java"])
            artifactId = "tacky"
        }
    }
    repositories {
        maven {
            name = "embedded"
            url = uri(rootProject.layout.buildDirectory.dir("repo"))
        }
    }
}
