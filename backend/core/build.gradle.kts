plugins {
  alias(libs.plugins.kotlin.jvm)
}

dependencies {
  implementation(project(":backend:api"))
  implementation(libs.jbcrypt)
  implementation(libs.ktor.http.jvm)
  testImplementation(libs.kotlin.test.junit)
  testImplementation(libs.junit.jupiter.api)
  testRuntimeOnly(libs.junit.jupiter.engine)
  // Gradle 9 removed the implicit injection of junit-platform-launcher from its
  // own distribution, so it must now be declared. Without it every `test` task
  // fails with "Failed to load JUnit Platform".
  testRuntimeOnly(libs.junit.platform.launcher)
}

tasks.withType<Test> {
  useJUnitPlatform()
}