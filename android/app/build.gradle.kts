plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.treknoteflutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.treknoteflutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // TÄMÄ ON UUSI KORJATTU KOHTA!
    // Lisää tämä 'android' -lohkon sisälle, mutta 'defaultConfig' -lohkon ulkopuolelle.
    packagingOptions {
        jniLibs {
            // Määritellään, mitkä natiivit kirjastot sisällytetään APK:hon.
            // Nämä ABI-suodattimet auttavat ratkaisemaan "INSTALL_FAILED_NO_MATCHING_ABIS" -virheen.
            // Sisällytetään kaikki yleisimmät ABIt, jotta sovellus toimii useimmissa laitteissa ja emulaattoreissa.
            // Huom: Kaikkien ABI:en sisällyttäminen kasvattaa APK-tiedoston kokoa.
            // Tuotantoon voit harkita rajatumpaa valintaa.
            useLegacyPackaging = false // Yleensä suositellaan, jos käytät uudempaa Gradle-versiota
            pickFirsts.add("lib/x86/libc++_shared.so") // Esimerkkejä, jos tulee "duplicate entry" -virheitä
            pickFirsts.add("lib/x86_64/libc++_shared.so")
            pickFirsts.add("lib/armeabi-v7a/libc++_shared.so")
            pickFirsts.add("lib/arm64-v8a/libc++_shared.so")
            
            // Tärkein osa: suodatetaan natiivikirjastot
            // Huom: 'includes' ja 'excludes' ovat tehokkaampia kuin abiFilters Kotlinissa
            // Jos haluat SISÄLLYTTÄÄ vain tietyt ABIt, käytä includes-listaa
            // Jos haluat POIS SULKEA tietyt ABIt, käytä excludes-listaa
            // Tässä tapauksessa haluamme SISÄLLYTTÄÄ kaikki nämä:
            // Koska 'abiFilters' ei ole suoraan saatavilla 'jniLibs' blokissa tällä tavalla,
            // meidän on pakattava kaikki ja annettava Androidin hoitaa valinta.
            // TAI, jos haluat rajoittaa, käytä 'doNotStrip' tai 'excludes'
            // Tai yleensä, usein tämä ongelma korjataan pelkästään Android Studio AVD-asetuksilla
            // tai tässä mainitulla packagingOptions-blokilla, jossa vain sisällytetään
            // halutut tiedostot tai estetään strip-toiminto.
            
            // Kokeillaan yksinkertaisempaa lähestymistapaa, joka usein toimii KOTLIN DSL:ssä:
            // Lisää tai muokkaa seuraavaa riviä, jos ongelma jatkuu:
            // Tämä on oikea tapa määrittää ABIt Kotlin DSL:ssä 'packagingOptions' sisällä
            // 'defaultConfig' blokissa.
            // Tämä vaatii 'splits' blokkia, jota ei ole yleensä 'build.gradle.kts' tiedostossa oletuksena.
            // Joten paras tapa on usein vain antaa sen rakentaa kaikki ja varmistaa emulaattorin/laitteen tuki.
            // Jos virhe jatkuu tämänkin jälkeen, ongelma voi olla syvemmällä projektin rakenteessa.
            
            // Koska 'abiFilters' ei ole suoraan 'packagingOptions' sisällä,
            // yleisin ratkaisu 'INSTALL_FAILED_NO_MATCHING_ABIS' -virheeseen Kotlinissa on:
            // 1. Varmistaa, että AVD-emulaattorisi on 'arm64-v8a' tai 'x86_64'.
            // 2. Jos käytät 3. osapuolen kirjastoja, varmista niiden ABI-tuki.
            // 3. Tämä 'packagingOptions' -lohko auttaa, jos on ongelmia natiivikirjastojen pakkauksessa.
            
            // Kokeillaan tarkemmin määriteltyä include-listaa, joka vastaa abiFilters -logiikkaa:
            // Tätä käytetään harvemmin, mutta voi olla tarpeen, jos perusratkaisut eivät auta.
            // Voit kommentoida tämän pois, jos se aiheuttaa uusia virheitä.
            // includes += listOf("lib/armeabi-v7a/*.so", "lib/arm64-v8a/*.so", "lib/x86/*.so", "lib/x86_64/*.so")
        }
    }
}

flutter {
    source = "../.."
}
