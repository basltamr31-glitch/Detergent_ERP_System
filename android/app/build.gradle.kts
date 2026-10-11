import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeys = Properties()
val releaseKeyFile = rootProject.file("key.properties")
if (releaseKeyFile.exists()) releaseKeyFile.inputStream().use { releaseKeys.load(it) }
val releaseRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val releaseApplicationId = providers.gradleProperty("erpApplicationId").orNull
val hasReleaseKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
    !releaseKeys.getProperty(it).isNullOrBlank()
}
if (releaseRequested && (releaseApplicationId.isNullOrBlank() || !hasReleaseKeys)) {
    throw GradleException("Release requires -PerpApplicationId=<owner application ID> and private android/key.properties. See RELEASE_GUIDE.md. Debug keys are never used for a release.")
}

android {
    namespace = "com.example.detergent_factory"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = releaseApplicationId ?: "com.example.detergent_factory"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeys) create("release") {
            storeFile = rootProject.file(releaseKeys.getProperty("storeFile"))
            storePassword = releaseKeys.getProperty("storePassword")
            keyAlias = releaseKeys.getProperty("keyAlias")
            keyPassword = releaseKeys.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeys) signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
