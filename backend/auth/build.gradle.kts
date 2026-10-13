plugins {
  alias(libs.plugins.kotlin.jvm)
}

dependencies {
  implementation(project(":backend:api"))
  implementation(project(":backend:core"))
  implementation(project(":backend:data"))
  implementation(libs.ktor.server.auth.jvm)
  implementation(libs.ktor.server.auth.jwt.jvm)
  // No `jbcrypt`: password hashing goes through `core`'s `PasswordHasher`, which
  // is the only place that needs to know which library is behind it.
  implementation(libs.ktor.server.core.jvm)
  implementation(libs.koin.ktor)
}