plugins {
    alias(libs.plugins.kotlin.jvm)
}

dependencies {
    implementation(project(":backend:core"))
    implementation(project(":backend:api"))
    implementation(libs.exposed.core)
    implementation(libs.exposed.dao)
    implementation(libs.exposed.jdbc)
    implementation(libs.postgresql)
}