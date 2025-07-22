plugins {
    alias(libs.plugins.kotlin.jvm)
}

dependencies {
    implementation(project(":teven-backend:api"))
    implementation("org.mindrot:jbcrypt:0.4")
}