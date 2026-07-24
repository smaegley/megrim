import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional release signing. Create android/key.properties (git-ignored) with:
//   storeFile=/absolute/path/to/megrim-release.jks
//   storePassword=...
//   keyAlias=...
//   keyPassword=...
// When absent (e.g. local dev, CI analyze/test), the release build falls back to debug keys.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "org.maegley.megrim"
    // Pinned to 36: some transitive plugins require compiling against API 36.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Application id is IMMUTABLE once published. Reverse-domain of maegley.org (a domain the
        // author controls); independent of the GitHub repo and of the maegley.com email domain.
        applicationId = "org.maegley.megrim"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // Fall back to debug keys so `flutter build apk --release` works without a keystore.
                signingConfigs.getByName("debug")
            }
            // Minification is required for F-Droid: R8 tree-shakes Flutter's unused
            // deferred-components embedding classes, whose references to Google Play Core
            // (a non-free library Megrim never uses) otherwise trip F-Droid's APK scanner.
            // See proguard-rules.pro before adding any -keep rule for io.flutter.**.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Don't embed Google Play's encrypted dependency-metadata signing block (only readable by
    // Google Play; flagged by F-Droid's scanner as an opaque blob).
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

// Per-ABI versionCodes for `--split-per-abi` builds (required by F-Droid, which publishes one APK
// per architecture and needs each to carry a distinct versionCode): base*10 + an ABI digit, e.g.
// versionCode 5 -> 51/52/53. Universal builds (our own release CI) have no ABI filter, so their
// versionCode stays the plain base value — the two release channels don't interfere.
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode = abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode * 10 + abiVersionCode
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
