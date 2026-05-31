plugins {
    id("com.android.application")
    id("kotlin-android")
    id("kotlin-parcelize")   // Samsung Health Data SDK 모델 직렬화용
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hannam.blowfit.blowfit"
    // Samsung Health Data SDK 의존성(androidx.activity 1.10 / lifecycle 2.9)이 최신 API 요구.
    compileSdk = 36
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
        applicationId = "com.hannam.blowfit.blowfit"
        // Samsung Health Data SDK 는 Android 10(API 29)+ 필요 (flutter_blue_plus 는 21+).
        minSdk = 29
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

dependencies {
    // Samsung Health Data SDK (로컬 AAR — 전이 의존성 수동 명시).
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar"))))
    implementation("com.google.code.gson:gson:2.13.1")
    implementation("androidx.activity:activity-ktx:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.9.2")
    // SDK 가 suspend(코루틴) 기반 — 로컬 AAR 이라 전이 의존성 수동 명시.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
