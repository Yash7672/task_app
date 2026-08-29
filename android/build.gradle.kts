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
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    project.plugins.withId("com.android.library") {
        project.afterEvaluate {
            val buildDir = project.layout.buildDirectory
            buildDir.dir("intermediates/aar_metadata_check/release/checkReleaseAarMetadata").get().asFile.mkdirs()
            buildDir.dir("intermediates/aar_metadata_check/debug/checkDebugAarMetadata").get().asFile.mkdirs()
            project.tasks.matching {
                it.name == "checkReleaseAarMetadata" || it.name == "checkDebugAarMetadata"
            }.configureEach {
                actions.clear()
            }
        }
    }
}

subprojects {
    project.plugins.withId("com.android.library") {
        project.afterEvaluate {
            val android = project.extensions.findByName("android")
            if (android != null) {
                val ns = android::class.java.getMethod("getNamespace").invoke(android) as? String
                if (ns.isNullOrEmpty()) {
                    android::class.java.getMethod("setNamespace", String::class.java)
                        .invoke(android, "com.example.${project.name}")
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
