plugins {
  alias(libs.plugins.kotlin.jvm)
}

dependencies {
  implementation(project(":backend:api"))
  implementation(project(":backend:core"))
  implementation(project(":backend:data"))
  implementation(libs.ktor.server.auth.jvm)
  implementation(libs.ktor.server.auth.jwt.jvm)
  implementation(libs.jbcrypt)
}