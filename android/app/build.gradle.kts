import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Signing config — citit din android/key.properties (EXCLUS din git) ────────
// Generează keystore cu: keytool -genkey -v -keystore proventaris-release.jks
//   -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias proventaris
// Creează android/key.properties cu valorile reale (vezi key.properties.template)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "ro.proterm.proventaris"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // ── Product flavors — identitate de pachet separată per client ────────────
    // proterm → ro.proterm.proventaris          (PRO TERM SRL, devizpro-ultra-pilot)
    // costel  → ro.proterm.proventaris.costel   (Costel Costea, proventaris-costel-costea)
    // Fiecare flavor are propriul google-services.json:
    //   proterm → android/app/google-services.json (root)
    //   costel  → android/app/src/costel/google-services.json
    // Package-uri diferite ⇒ cele două aplicații coexistă pe același device
    // (fără suprascriere / coliziune de date).
    flavorDimensions += "client"
    productFlavors {
        create("proterm") {
            dimension = "client"
            applicationId = "ro.proterm.proventaris"
        }
        create("costel") {
            dimension = "client"
            applicationId = "ro.proterm.proventaris.costel"
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        // applicationId este definit per flavor (proterm / costel) — vezi productFlavors.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Dacă key.properties există → semnare cu keystore de producție
            // Dacă nu există → fallback la debug (NUMAI pentru development local)
            signingConfig = if (keystorePropertiesFile.exists() &&
                                signingConfigs.names.contains("release")) {
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
