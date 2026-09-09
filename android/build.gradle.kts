allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// isar_flutter_libs 3.1.0+1 is unmaintained and predates two AGP 8 rules: it
// declares no `namespace` (AGP stopped reading `package` from the plugin's own
// AndroidManifest) and it compiles against android-30, below the 33 that
// AndroidX now requires. Patch both here rather than forking the package.
// Remove this once the app moves to a maintained Isar fork.
subprojects {
    afterEvaluate {
        val androidExtension = extensions.findByName("android") ?: return@afterEvaluate
        val methods = androidExtension.javaClass.methods

        val getNamespace = methods.firstOrNull { it.name == "getNamespace" && it.parameterCount == 0 }
        val setNamespace = methods.firstOrNull { it.name == "setNamespace" && it.parameterCount == 1 }
        if (getNamespace != null && setNamespace != null &&
            getNamespace.invoke(androidExtension) == null
        ) {
            val manifest = project.file("src/main/AndroidManifest.xml")
            val declaredPackage =
                if (manifest.exists()) {
                    Regex("package=\"([^\"]+)\"").find(manifest.readText())?.groupValues?.get(1)
                } else {
                    null
                }
            val recovered = declaredPackage ?: project.group.toString().takeIf { it.isNotBlank() }
            if (recovered != null) {
                logger.lifecycle("Patching namespace for ${project.name}: $recovered")
                setNamespace.invoke(androidExtension, recovered)
            }
        }

        val getCompileSdk = methods.firstOrNull { it.name == "getCompileSdk" && it.parameterCount == 0 }
        val setCompileSdk = methods.firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
        if (getCompileSdk != null && setCompileSdk != null) {
            val current = getCompileSdk.invoke(androidExtension) as? Int
            if (current != null && current < 33) {
                logger.lifecycle("Raising compileSdk for ${project.name}: $current -> 36")
                setCompileSdk.invoke(androidExtension, 36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
