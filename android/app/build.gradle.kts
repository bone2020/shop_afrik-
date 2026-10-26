plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// A staging build (`flutter run --dart-define=KARTAFRIK_ENV=staging`) installs
// as its own app, "KartAfrik Staging", next to the real one. Flutter hands the
// dart-defines to Gradle base64-encoded and comma-separated.
val isStaging = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.map { String(java.util.Base64.getDecoder().decode(it)) }
    ?.contains("KARTAFRIK_ENV=staging") == true

android {
    namespace = "com.shopafrik.shop_afrik"
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
        applicationId = if (isStaging) "com.shopafrik.app.staging" else "com.shopafrik.app"
        resValue("string", "app_name", if (isStaging) "KartAfrik Staging" else "shop_afrik")
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
