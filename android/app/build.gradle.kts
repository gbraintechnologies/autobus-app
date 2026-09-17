import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

val versionPropertiesFile = rootProject.file("version.properties")
val versionProperties = Properties()
if (versionPropertiesFile.exists()) {
    versionProperties.load(FileInputStream(versionPropertiesFile))
}

val storedVersionCode = versionProperties
    .getProperty("VERSION_CODE", flutter.versionCode.toString())
    .toInt()

// Flutter invokes `bundleRelease` for `flutter build appbundle`. Matching any
// task that merely contains "release" also bumped the file during
// `flutter run --release` / APK builds, while the AAB kept the old code.
val isBundleReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("bundleRelease", ignoreCase = true)
}

val appVersionCode: Int = run {
    val extras = rootProject.extensions.extraProperties
    if (extras.has("autobusVersionCode")) {
        extras.get("autobusVersionCode") as Int
    } else if (isBundleReleaseBuild) {
        val next = storedVersionCode + 1
        versionProperties.setProperty("VERSION_CODE", next.toString())
        versionPropertiesFile.outputStream().use { stream ->
            versionProperties.store(stream, "Android versionCode; bumped on bundleRelease")
        }
        extras.set("autobusVersionCode", next)
        logger.warn("Bumping Android versionCode to $next for Play Store AAB")
        next
    } else {
        extras.set("autobusVersionCode", storedVersionCode)
        storedVersionCode
    }
}

android {
    namespace = "com.autobus.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.autobus.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = appVersionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                storeFile = keyProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keyProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

// AGP 8+ can ignore defaultConfig.versionCode on some outputs; pin it on every variant.
androidComponents {
    onVariants { variant ->
        variant.outputs.forEach { output ->
            output.versionCode.set(appVersionCode)
        }
    }
}