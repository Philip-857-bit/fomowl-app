import java.io.File
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun signingValue(propertyKey: String, envKey: String): String? {
    return (keystoreProperties.getProperty(propertyKey) ?: System.getenv(envKey))
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
}

fun resolveSigningStoreFile(path: String?): File? {
    val trimmed = path?.trim()?.takeIf { it.isNotEmpty() } ?: return null
    val direct = File(trimmed)
    if (direct.isAbsolute) {
        return direct
    }

    val androidRootRelative = rootProject.file(trimmed)
    if (androidRootRelative.exists()) {
        return androidRootRelative
    }

    val moduleRelative = project.file(trimmed)
    if (moduleRelative.exists()) {
        return moduleRelative
    }

    return androidRootRelative
}

val releaseStoreFile = resolveSigningStoreFile(signingValue("storeFile", "KEYSTORE_FILE"))
val releaseStorePassword = signingValue("storePassword", "KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "KEY_PASSWORD")
val hasReleaseSigning =
    releaseStoreFile != null &&
    releaseStorePassword != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null

fun isReleaseTaskRequested(): Boolean {
    val requestedTasks = gradle.startParameter.taskNames
    if (requestedTasks.isEmpty()) return false
    return requestedTasks.any { taskName ->
        val normalized = taskName.lowercase()
        normalized.contains("release") || normalized.contains("publish")
    }
}

android {
    namespace = "com.fomowl.owllet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.fomowl.owllet"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

if (isReleaseTaskRequested() && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is not configured. Provide android/key.properties or KEYSTORE_FILE, KEYSTORE_PASSWORD, KEY_ALIAS, and KEY_PASSWORD."
    )
}

flutter {
    source = "../.."
}
