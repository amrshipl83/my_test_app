plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.aksabeg500"
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
        applicationId = "com.aksabeg500"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // 💡 التبعيات الأساسية
    implementation("androidx.multidex:multidex:2.0.1")

    // 🆕 إضافة تبعيات Firebase platform لتجنب مشاكل التوافق بين مكتبات Firebase المختلفة
    // هذا يحل مشكلات التبعيات القديمة.
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
}

flutter {
    source = "../.."
}
