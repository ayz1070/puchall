import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun envValue(environment: String, key: String): String? {
    val envFile = rootProject.file("../.env.$environment")
    if (!envFile.exists()) return null

    val properties = Properties()
    envFile.inputStream().use { properties.load(it) }
    return properties.getProperty(key)?.trim()?.takeIf { it.isNotEmpty() }
}

fun admobAndroidAppId(environment: String): String {
    return envValue(environment, "ADMOB_ANDROID_APP_ID")
        ?: "ca-app-pub-3940256099942544~3347511713"
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.puchall.puchall"
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
        applicationId = "com.puchall.puchall"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Puchall DEV")
            manifestPlaceholders["admobApplicationId"] = admobAndroidAppId("dev")
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "Puchall")
            manifestPlaceholders["admobApplicationId"] = admobAndroidAppId("prod")
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
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
