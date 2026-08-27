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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
