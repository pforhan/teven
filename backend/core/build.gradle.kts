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
}

tasks.withType<Test> {
    useJUnitPlatform()
}