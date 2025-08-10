import org.jetbrains.dokka.gradle.DokkaTask

plugins {
    kotlin("jvm")
    kotlin("plugin.serialization")
    id("org.jetbrains.dokka")
}

repositories {
    mavenCentral()
}

dependencies {
    implementation(libs.kotlin.stdlib.jdk8)
    implementation(libs.kotlinx.serialization.json)
}

// Configure the GFM task
tasks.named<DokkaTask>("dokkaGfm") {
    outputDirectory.set(layout.buildDirectory.dir("dokka-gfm"))
    dokkaSourceSets.configureEach {
        // Only document the api models
        sourceRoots.from(file("src/main/kotlin/com/teven/api/model"))
        // Don't show inherited members from Any, etc.
        suppressInheritedMembers.set(true)
    }
}

