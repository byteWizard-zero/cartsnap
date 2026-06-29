plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.onebitvscoder.cartsnap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // 🚀 This explicitly fixes the Line 19 error!
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.onebitvscoder.cartsnap"
        
        // 🚀 This explicitly fixes the Line 27 error!
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
