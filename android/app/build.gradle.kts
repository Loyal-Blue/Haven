plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val havenReleaseKey = System.getenv("HAVEN_RELEASE_KEYSTORE")

android {
    namespace = "app.havenlife.haven"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.havenlife.haven"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (havenReleaseKey != null) {
            create("havenRelease") {
                storeFile = file(havenReleaseKey)
                storePassword = System.getenv("HAVEN_RELEASE_STORE_PASSWORD")
                keyAlias = System.getenv("HAVEN_RELEASE_KEY_ALIAS")
                keyPassword = System.getenv("HAVEN_RELEASE_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            val keyName = if (havenReleaseKey == null) "debug" else "havenRelease"
            signingConfig = signingConfigs.getByName(keyName)
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
