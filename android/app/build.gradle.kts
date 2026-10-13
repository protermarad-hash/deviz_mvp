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

// ── Gardă semnare release (fail-closed) — vezi docs/BUILD_AND_RELEASE_POLICY.md §7 ──
// Un build release fără configurație completă de semnare NU mai cade tacit pe
// certificatul debug (incidentul 1.13.0+113): build-ul eșuează. Mesajele numesc
// doar cheile lipsă — niciodată valori, parole sau path-uri.
// Excepție explicită, doar pentru artefacte TEST ONLY:
//   PROVENTARIS_ALLOW_DEBUG_SIGNED_RELEASE=1
// Build-urile debug/profile (inclusiv CI) nu sunt afectate.
val requiredSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningKeys = requiredSigningKeys.filter {
    keystoreProperties.getProperty(it).isNullOrBlank()
}
val releaseStoreFileExists = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { project.file(it).exists() } == true
val releaseSigningReady = keystorePropertiesFile.exists() &&
    missingSigningKeys.isEmpty() && releaseStoreFileExists
val allowDebugSignedRelease =
    providers.environmentVariable("PROVENTARIS_ALLOW_DEBUG_SIGNED_RELEASE").orNull == "1"

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
        if (releaseSigningReady) {
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
            // Configurație completă → semnare cu keystore de producție.
            // Altfel → debug DOAR ca valoare de configurare; garda de mai jos
            // oprește orice task release, cu excepția opt-in-ului TEST ONLY.
            signingConfig = if (releaseSigningReady) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseTaskPattern = Regex("^(assemble|bundle|package)\\w*Release$")
    val runsRelease = allTasks.any {
        it.project == project && releaseTaskPattern.matches(it.name)
    }
    if (!runsRelease || releaseSigningReady) return@whenReady
    val reason = when {
        !keystorePropertiesFile.exists() -> "android/key.properties lipsește"
        missingSigningKeys.isNotEmpty() ->
            "android/key.properties nu conține: ${missingSigningKeys.joinToString()}"
        else -> "fișierul keystore indicat de storeFile nu există"
    }
    if (allowDebugSignedRelease) {
        logger.warn(
            "ATENȚIE: build release semnat cu certificatul DEBUG ($reason). " +
                "Artefact TEST ONLY — NOT DISTRIBUTABLE."
        )
    } else {
        throw GradleException(
            "Semnare release indisponibilă: $reason. Build oprit (fail-closed) " +
                "ca să nu rezulte un APK release semnat debug. Pentru un artefact " +
                "TEST ONLY setați explicit PROVENTARIS_ALLOW_DEBUG_SIGNED_RELEASE=1. " +
                "Vezi docs/BUILD_AND_RELEASE_POLICY.md §7."
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
