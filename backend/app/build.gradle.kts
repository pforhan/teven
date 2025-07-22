plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.ktor)
    alias(libs.plugins.kotlin.serialization)
}

application {
    mainClass.set("com.teven.ApplicationKt")
}

dependencies {
    implementation(project(":backend:service"))
    implementation(project(":backend:api"))
    implementation(project(":backend:data"))
    implementation(libs.ktor.server.core.jvm)
    implementation(libs.ktor.server.netty.jvm)
    implementation(libs.ktor.server.content.negotiation.jvm)
    implementation(libs.ktor.serialization.kotlinx.json.jvm)
    implementation(libs.koin.ktor)
    implementation(libs.koin.logger.slf4j)
}