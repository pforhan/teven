plugins {
  alias(libs.plugins.kotlin.jvm)
}

dependencies {
  implementation(project(":backend:api"))
  implementation(libs.jbcrypt)
  implementation(libs.ktor.http.jvm)
}