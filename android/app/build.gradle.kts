plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")        // ⬅️ ضروري للفirebase
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.my_test_app"
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
        applicationId = "com.example.my_test_app"
        minSdk = 23                                // ⬅️ firebase messaging يتطلب 23 أو أعلى
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true                    // ⬅️ ضروري جدًا
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false               // ⬅️ عطل الـ shrink عشان ما يكسر الفايربيز
            isShrinkResources = false
        }
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")   // ⬅️ مهم جدًا
}

flutter {
    source = "../.."
}
