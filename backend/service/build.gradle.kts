plugins {
    alias(libs.plugins.kotlin.jvm)
}

dependencies {
    implementation(project(":backend:data"))
    implementation(project(":backend:auth"))
    implementation(project(":backend:api"))
    implementation(project(":backend:core"))
}