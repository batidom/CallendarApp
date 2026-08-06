pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Pinned to AGP 8.x rather than the `flutter create` default of 9.x: AGP 9's
// built-in Kotlin support isn't yet handled correctly by some plugins
// (file_picker 11.0.3 skips applying its own Kotlin plugin on AGP 9+ but
// doesn't opt into AGP's built-in Kotlin either, so its classes never get
// compiled). AGP 8.x + an explicit Kotlin plugin is the well-supported path.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
