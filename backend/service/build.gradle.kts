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
  implementation(libs.koin.core)
  testImplementation(libs.kotlin.test.junit)
  testImplementation(libs.junit.jupiter.api)
  testRuntimeOnly(libs.junit.jupiter.engine)
  testImplementation(libs.mockk)
}

tasks.withType<Test> {
    useJUnitPlatform()
}