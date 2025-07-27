plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.ktor)
}

dependencies {
    implementation(project(":backend:data"))
    implementation(project(":backend:auth"))
    implementation(project(":backend:api"))
    implementation(project(":backend:core"))
    implementation(libs.ktor.server.auth.jwt.jvm)
}