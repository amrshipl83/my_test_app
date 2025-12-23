// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.aksabeg500"
    
    // 🎯 قمنا بتثبيت النسخة على 34 بدلاً من flutter.compileSdkVersion لتجنب مشاكل API 36
    compileSdk = 34
    
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // تفعيل Desugaring ضروري جداً لدعم الإشعارات على الأجهزة القديمة والحديثة
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.aksabeg500"
        
        // 🎯 نستخدم 24 كحد أدنى و 34 كهدف مستقر
        minSdk = 24 
        targetSdk = 34 
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // بما أننا في مرحلة التيست، نستخدم توقيع الـ debug لضمان عمل الـ APK
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // مكتبة Desugaring لحل مشاكل التوافق مع الوقت والتاريخ والإشعارات
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // دعم تعدد ملفات الـ DEX للأجهزة القديمة
    implementation("androidx.multidex:multidex:2.0.1")

    // Firebase BoM لضمان توافق إصدارات مكتبات فايربيز مع بعضها
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")
}

flutter {
    source = "../.."
}

