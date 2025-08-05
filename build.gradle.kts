// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    // Apply common plugins here, without versions (versions come from libs.versions.toml)
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.ktor) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.dokka) apply false
}

allprojects {
    group = "com.teven"
    version = "0.0.1"

    repositories {
        mavenCentral()
    }
}

subprojects {
    apply(plugin = "org.jetbrains.dokka")
}

tasks.register("generateApiDocs") {
    group = "documentation"
    description = "Generates API.md from API_TEMPLATE.md and Dokka output."

    dependsOn(":backend:api:dokkaGfm")
    shouldRunAfter(":backend:api:dokkaGfm")

    val dokkaOutput = project(":backend:api").layout.buildDirectory.dir("dokka-gfm")
    val apiTemplate = rootProject.file("API_TEMPLATE.md")
    val apiOutput = rootProject.file("API.md")

    inputs.file(apiTemplate)
    inputs.dir(dokkaOutput)
    outputs.file(apiOutput)

    doLast {
        val dataModelMap = dokkaOutput.get().asFile.walk()
            .filter { it.isFile && it.name.endsWith(".md") }
            .sortedBy { it.path }
            .mapNotNull { file ->
                val line = file.readLines().find { it.startsWith("data class") || it.startsWith("enum class") }
                if (line != null) {
                    val cleanedLine = line.replace(Regex("\\[(.*?)\\]\\(.*?\\)"), "$1") // Remove markdown links
                    val classNameMatch = Regex("(data|enum) class (\\w+)").find(cleanedLine)
                    val className = classNameMatch?.groupValues?.get(2)
                    if (className != null) {
                        // link to class name and split each var into a new line
                        val formattedClass = cleanedLine
                            .replace("val", "\n          val")
                            .replace(" = null", "")
                            .replace("&lt;","<")
                            .replace("&gt;",">")
                            .replace(")", "\n        )")
                        className to formattedClass
                    } else {
                        null
                    }
                } else {
                    null
                }
            }
            .associate { it }
            .toSortedMap()

        var templateContent = apiTemplate.readText()

        // Perform inline replacements
        dataModelMap.forEach { (modelName, modelDefinition) ->
            templateContent = templateContent.replace("<!-- DATA_MODEL_${modelName} -->", "```kotlin\n        ${modelDefinition}\n        ```")
        }

        // Inject all models at the end, removing their extra indentation.
        val allModelsContent =
            dataModelMap.values.joinToString(separator = "\n\n") { it }.replace("        ", "")
        val finalContent = templateContent.replace(
            "<!-- INJECT_API_MODELS_HERE -->",
            "### Data Models\n\n```kotlin\n" + allModelsContent + "\n```"
        )
        apiOutput.writeText(finalContent)
    }
}
