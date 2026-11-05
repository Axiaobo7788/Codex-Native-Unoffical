import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties()
if (releaseSigningPropertiesFile.isFile) {
    FileInputStream(releaseSigningPropertiesFile).use(releaseSigningProperties::load)
}

val requiredReleaseSigningProperties =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingReleaseSigningProperties =
    requiredReleaseSigningProperties.filter {
        releaseSigningProperties.getProperty(it).isNullOrBlank()
    }
val releaseStoreFile =
    releaseSigningProperties
        .getProperty("storeFile")
        ?.takeIf(String::isNotBlank)
        ?.let(rootProject::file)
val hasCompleteReleaseSigning =
    releaseSigningPropertiesFile.isFile &&
        missingReleaseSigningProperties.isEmpty() &&
        releaseStoreFile?.let { it.isFile && it.canRead() } == true

android {
    namespace = "io.github.axiaobo7788.codex_native_unofficial"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.github.axiaobo7788.codex_native_unofficial"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasCompleteReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseSigningProperties.getProperty("storePassword")
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasCompleteReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// Do not let an unsigned or debug-signed artifact masquerade as a release.
// Delaying the check until the release task executes keeps debug development and
// IDE sync usable without access to the operator's private upload key.
tasks.configureEach {
    if (name == "preReleaseBuild") {
        doFirst {
            when {
                !releaseSigningPropertiesFile.isFile ->
                    throw GradleException(
                        "Android release signing is not configured. " +
                            "Copy android/key.properties.example to " +
                            "android/key.properties and provide an external upload keystore.",
                    )
                missingReleaseSigningProperties.isNotEmpty() ->
                    throw GradleException(
                        "Android release signing is incomplete; missing properties: " +
                            missingReleaseSigningProperties.joinToString(", "),
                    )
                releaseStoreFile?.let { it.isFile && it.canRead() } != true ->
                    throw GradleException(
                        "Android release signing storeFile is not a readable file.",
                    )
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
