plugins {
  alias(libs.plugins.kotlin.jvm)
  alias(libs.plugins.ktor)
  alias(libs.plugins.kotlin.serialization)
}

application {
  mainClass.set("com.teven.ApplicationKt")
}

dependencies {
  implementation(project(":backend:api"))
  implementation(project(":backend:core"))
  implementation(project(":backend:data"))
  implementation(project(":backend:service"))
  implementation(libs.ktor.server.auth.jwt.jvm)
  implementation(libs.ktor.server.core.jvm)
  implementation(libs.ktor.server.netty.jvm)
  implementation(libs.ktor.server.content.negotiation.jvm)
  implementation(libs.ktor.server.status.pages)
  implementation(libs.ktor.serialization.kotlinx.json.jvm)
  implementation(libs.koin.ktor)
  implementation(libs.koin.logger.slf4j)
}