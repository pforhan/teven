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
  testImplementation(libs.kotlin.test.junit)
  testImplementation(libs.junit.jupiter.api)
  testRuntimeOnly(libs.junit.jupiter.engine)
  // Gradle 9 removed the implicit injection of junit-platform-launcher from its
  // own distribution, so it must now be declared. Without it every `test` task
  // fails with "Failed to load JUnit Platform".
  testRuntimeOnly(libs.junit.platform.launcher)
  testImplementation(libs.mockk)
}

tasks.withType<Test> {
  useJUnitPlatform()
}