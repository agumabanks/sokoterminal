import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google services for Firebase
    id("com.google.gms.google-services")
    // Crashlytics Gradle plugin (mapping upload for release builds)
    id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val isReleaseBuild = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }

fun readSecret(propKey: String, envKey: String): String? {
    val fromProp = keystoreProperties.getProperty(propKey)?.trim()?.takeIf { it.isNotEmpty() }
    val fromEnv = System.getenv(envKey)?.trim()?.takeIf { it.isNotEmpty() }
    return fromProp ?: fromEnv
}

val releaseStoreFile = readSecret("storeFile", "STORE_FILE")
val releaseStorePassword = readSecret("storePassword", "STORE_PASSWORD")
val releaseKeyAlias = readSecret("keyAlias", "KEY_ALIAS")
val releaseKeyPassword = readSecret("keyPassword", "KEY_PASSWORD")

val hasReleaseSigning =
    releaseStoreFile != null &&
        releaseStorePassword != null &&
        releaseKeyAlias != null &&
        releaseKeyPassword != null &&
        rootProject.file(releaseStoreFile).exists()

if (isReleaseBuild && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is not configured. Create android/key.properties (see key.properties.example) " +
            "or set STORE_FILE/STORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD env vars.",
    )
}

android {
    namespace = "com.soko24.soko_seller_terminal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.soko24.soko_seller_terminal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = rootProject.file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseSigning) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")

            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
