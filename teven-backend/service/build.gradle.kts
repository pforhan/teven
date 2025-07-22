plugins {
    alias(libs.plugins.kotlin.jvm)
}

dependencies {
    implementation(project(":teven-backend:data"))
    implementation(project(":teven-backend:auth"))
    implementation(project(":teven-backend:api"))
    implementation(project(":teven-backend:core"))
}