plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // Apply Google Services Plugin
}

android {
    namespace = "com.example.flutter_application_1"
    // نرفع الـ SDK لـ 34 عشان نتفادى مشاكل الأندرويد الجديد مع النوتيفيكيشن
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // تفعيل الـ Desugaring هنا
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.flutter_application_1"
        // الـ minSdk لازم يكون 21 على الأقل لضمان عمل المكتبات
        minSdk = flutter.minSdkVersion 
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // تفعيل الـ MultiDex لو المشروع كبر
        multiDexEnabled = true
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

dependencies {
    // إدخال المكتبة المسؤولة عن حل المشكلة (Desugaring)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
    
    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.11.0"))
    implementation("com.google.firebase:firebase-analytics")
}
