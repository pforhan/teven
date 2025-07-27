plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.ktor)
    alias(libs.plugins.kotlin.serialization)
}

application {
    mainClass.set("com.teven.ApplicationKt")
}

val webappDir = file("../../frontend")

tasks.register("npmInstall", Exec::class) {
    workingDir = webappDir
    // Detect OS and set command accordingly
    val isWindows = System.getProperty("os.name").lowercase().contains("windows")
    commandLine = if (isWindows) {
        listOf("cmd", "/c", "npm", "install")
    } else {
        listOf("npm", "install")
    }
}

tasks.register("npmBuild", Exec::class) {
    dependsOn("npmInstall")
    workingDir = webappDir
    // Detect OS and set command accordingly
    val isWindows = System.getProperty("os.name").lowercase().contains("windows")
    commandLine = if (isWindows) {
        listOf("cmd", "/c", "npm", "run", "build")
    } else {
        listOf("npm", "run", "build")
    }
}

tasks.named<Copy>("processResources") {
    dependsOn("npmBuild")
    from("$webappDir/dist") {
        into("static")
    }
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