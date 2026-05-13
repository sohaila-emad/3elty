plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.11.0"))
    implementation("com.google.firebase:firebase-analytics")
    // Required by flutter_local_notifications for API < 26 desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

android {
    namespace = "com.example.flutter_application_1"

    // Pin explicitly so SCHEDULE_EXACT_ALARM and USE_EXACT_ALARM work correctly.
    // compileSdk 35 lets us declare USE_EXACT_ALARM (added in API 33).
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.flutter_application_1"
        // minSdk 21 is fine; SCHEDULE_EXACT_ALARM is declared but only
        // requested at runtime on API 31+ (guarded in notification_helper.dart).
        minSdk = flutter.minSdkVersion
        // targetSdk 34 required for USE_EXACT_ALARM to take effect on Android 14.
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
