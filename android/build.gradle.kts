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

// camera_android_camerax 0.6.x compiles against CameraX 1.5.x, whose API jar
// needs androidx.concurrent:concurrent-futures (CallbackToFutureAdapter) that
// the plugin never declares. AGP 9 fails javac without it.
subprojects {
    if (name == "camera_android_camerax") {
        project.plugins.withId("com.android.library") {
            project.dependencies.add(
                "implementation",
                "androidx.concurrent:concurrent-futures:1.2.0",
            )
        }
    }
}

// Some plugins (e.g. tflite_flutter) leave their Java compileOptions at an old
// target (11) while Kotlin defaults to the current JDK (24), which AGP 9/KGP
// reject as "Inconsistent JVM-target compatibility". Align any Kotlin compile
// task with the module's own Java target so the check passes.
subprojects {
    project.plugins.withId("com.android.library") {
        project.afterEvaluate {
            val android = project.extensions.findByName("android") ?: return@afterEvaluate
            val compileOptions =
                android::class.java.getMethod("getCompileOptions").invoke(android)
            val javaTarget =
                compileOptions::class.java
                    .getMethod("getTargetCompatibility")
                    .invoke(compileOptions)
                    .toString()
            val jvmTarget =
                try {
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTarget)
                } catch (_: Throwable) {
                    return@afterEvaluate
                }
            project.tasks
                .withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java)
                .configureEach {
                    compilerOptions.jvmTarget.set(jvmTarget)
                }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
