
// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    // Apply common plugins here, without versions (versions come from libs.versions.toml)
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.ktor) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}

allprojects {
    group = "com.teven"
    version = "0.0.1"

    repositories {
        mavenCentral()
    }
}
