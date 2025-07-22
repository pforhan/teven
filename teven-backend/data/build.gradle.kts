plugins {
    alias(libs.plugins.kotlin.jvm)
}

dependencies {
    implementation(project(":teven-backend:core"))
    implementation(project(":teven-backend:api"))
    implementation(libs.exposed.core)
    implementation(libs.exposed.dao)
    implementation(libs.exposed.jdbc)
    implementation(libs.postgresql)
}