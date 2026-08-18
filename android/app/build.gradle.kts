// `java.util.Properties` nao pode ser escrito por extenso aqui: dentro de um
// build.gradle.kts de app, `java` e a extensao Java do projeto e esconde o
// pacote. Por isso o import explicito.
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave de assinatura de release, se existir.
//
// O arquivo android/key.properties guarda a senha do keystore, entao ele NAO
// vai para o Git (esta no .gitignore). Quando ele nao existe -- que e o caso
// de quem acabou de clonar o projeto -- o build de release cai na chave de
// debug e continua funcionando normalmente. Ou seja: ninguem precisa criar
// chave nenhuma para conseguir compilar.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "com.example.robot_controller"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identificador unico do app no Android. `com.example.*` e o valor de
        // exemplo do Flutter: instala no celular sem problema, mas a Play
        // Store recusa. Veja "Identificador do app" no README.
        applicationId = "com.example.robot_controller"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Com key.properties presente, assina com a sua chave. Sem ele,
            // assina com a chave de debug -- o APK instala e roda, mas nao
            // serve para publicar na Play Store.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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
