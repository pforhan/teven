plugins {
  alias(libs.plugins.kotlin.jvm)
}

dependencies {
  implementation(project(":backend:api"))
  implementation(libs.ktor.server.auth.jvm)
  implementation(libs.ktor.server.auth.jwt.jvm)
}