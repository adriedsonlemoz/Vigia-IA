plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vigiaia.app"
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
        applicationId = "com.vigiaia.app"
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // No CI otimizado, uma unica tarefa Gradle gera o APK universal e os tres APKs por ABI.
    // Builds locais continuam com o comportamento padrao do Flutter.
    val multiApkCi = providers.environmentVariable("VIGIAIA_CI_MULTI_APK").orNull == "1"
    if (multiApkCi) {
        splits {
            abi {
                isEnable = true
                reset()
                include("armeabi-v7a", "arm64-v8a", "x86_64")
                isUniversalApk = true
            }
        }
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
            val keystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            val keyAliasValue = System.getenv("ANDROID_KEY_ALIAS")
            val keyPasswordValue = System.getenv("ANDROID_KEY_PASSWORD")

            if (keystorePath.isNullOrBlank() || keystorePassword.isNullOrBlank() ||
                keyAliasValue.isNullOrBlank() || keyPasswordValue.isNullOrBlank()) {
                throw GradleException("Secrets de assinatura release ausentes. Configure ANDROID_KEYSTORE_BASE64/PASSWORD/ALIAS/KEY_PASSWORD no GitHub.")
            }

            storeFile = rootProject.file(keystorePath)
            storePassword = keystorePassword
            keyAlias = keyAliasValue
            keyPassword = keyPasswordValue
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
