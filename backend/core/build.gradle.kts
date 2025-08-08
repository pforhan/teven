plugins {
  alias(libs.plugins.kotlin.jvm)
}

dependencies {
  implementation(project(":backend:api"))
  implementation("org.mindrot:jbcrypt:0.4")
  implementation(libs.ktor.http.jvm)
}