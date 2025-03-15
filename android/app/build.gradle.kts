plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.car_tracking_new"
    compileSdk = 35  // ✅ Update to match plugin requirement

    defaultConfig {
        applicationId = "com.example.car_tracking"
        minSdk = 21
        targetSdk = 35  // ✅ Update to match compileSdk
        versionCode = 1
        versionName = "1.0"

        ndkVersion = "27.0.12077973"  // ✅ Update NDK version
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            isMinifyEnabled = true  // Enable code shrinking
            isShrinkResources = true // Enable resource shrinking
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // ✅ Uncomment below if you have a signing config
            // signingConfig = signingConfigs.getByName("debug") 
        }
    }
}

flutter {
    source = "../.."
}
