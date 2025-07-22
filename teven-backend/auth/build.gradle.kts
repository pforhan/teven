plugins {
    alias(libs.plugins.kotlin.jvm)
}

dependencies {
    implementation(project(":teven-backend:api"))
    implementation(libs.ktor.server.auth.jvm)
    implementation(libs.ktor.server.auth.jwt.jvm)
}