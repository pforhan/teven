plugins {
  alias(libs.plugins.kotlin.jvm)
  alias(libs.plugins.ktor)
  alias(libs.plugins.kotlin.serialization)
}

application {
  mainClass.set("alphainterplanetary.teven.ApplicationKt")
}

dependencies {
  implementation(project(":backend:api"))
  implementation(project(":backend:core"))
  implementation(project(":backend:data"))
  implementation(project(":backend:service"))
  implementation(project(":backend:auth"))
  implementation(libs.ktor.server.auth.jwt.jvm)
  implementation(libs.ktor.server.core.jvm)
  implementation(libs.ktor.server.netty.jvm)
  implementation(libs.ktor.server.content.negotiation.jvm)
  implementation(libs.ktor.server.status.pages)
  implementation(libs.ktor.server.cors)
  implementation(libs.ktor.serialization.kotlinx.json.jvm)
  implementation(libs.koin.ktor)
  implementation(libs.koin.logger.slf4j)
  implementation(libs.logback.classic)

  testImplementation(libs.ktor.server.test.host.jvm)
  testImplementation(libs.koin.ktor)
  testImplementation(libs.koin.logger.slf4j)
  testImplementation(libs.kotlin.test.junit)
  testImplementation(libs.junit.jupiter.api)
  testRuntimeOnly(libs.junit.jupiter.engine)
  testRuntimeOnly(libs.junit.platform.launcher)
  testImplementation(libs.mockk)
}

tasks.withType<Test> {
  useJUnitPlatform()
}