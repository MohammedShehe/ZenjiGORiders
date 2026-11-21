import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing credentials are kept outside source control in android/key.properties.
val releaseSigningProperties = Properties()
val releaseSigningPropertiesFile = rootProject.file("key.properties")
val hasReleaseSigningProperties = releaseSigningPropertiesFile.exists()
if (hasReleaseSigningProperties) {
    releaseSigningPropertiesFile.inputStream().use { releaseSigningProperties.load(it) }
}

val releaseStoreFile = releaseSigningProperties.getProperty("storeFile")
val releaseStorePassword = releaseSigningProperties.getProperty("storePassword")
val releaseKeyAlias = releaseSigningProperties.getProperty("keyAlias")
val releaseKeyPassword = releaseSigningProperties.getProperty("keyPassword")
val hasCompleteReleaseSigning = hasReleaseSigningProperties &&
    !releaseStoreFile.isNullOrBlank() &&
    !releaseStorePassword.isNullOrBlank() &&
    !releaseKeyAlias.isNullOrBlank() &&
    !releaseKeyPassword.isNullOrBlank()

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val mapsApiKey = localProperties.getProperty("MAPS_API_KEY")
    ?: System.getenv("GOOGLE_MAPS_API_KEY_ANDROID")
    ?: ""

android {
    namespace = "com.zenjigo.riders"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.zenjigo.riders"
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        create("release") {
            if (hasCompleteReleaseSigning) {
                storeFile = rootProject.file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Never fall back to the debug certificate for a Play Store release.
            signingConfig = if (hasCompleteReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Fail clearly instead of silently producing an unsigned or debug-signed Play upload.
tasks.configureEach {
    if (name == "bundleRelease" || name == "assembleRelease") {
        doFirst {
            if (!hasCompleteReleaseSigning) {
                throw GradleException(
                    "Release signing is not configured. Create android/key.properties and " +
                        "android/upload-keystore.jks using RELEASE_SIGNING_README.md, then rebuild."
                )
            }
            val keystore = rootProject.file(releaseStoreFile!!)
            if (!keystore.isFile) {
                throw GradleException("Release keystore not found: ${keystore.absolutePath}")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.j2objc:j2objc-annotations:3.0.0")
}
