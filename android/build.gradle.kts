plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
}

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

// These plugins assume AGP 9 always uses built-in Kotlin and therefore do not
// apply KGP themselves. Flutter 3.44 temporarily opts existing applications out
// of built-in Kotlin while their plugin ecosystem migrates, so make sure their
// Kotlin sources are still compiled in that compatibility mode.
subprojects {
    if (name in setOf("file_picker", "mobile_scanner")) {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
