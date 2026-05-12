plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.example.minicpm_v_demo"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.minicpm_v_demo"
        // minSdk = 24 (Android 7.0) covers ~99% of in-use devices.
        // The native code only requires arm64-v8a (Android 5.0+), and the
        // app itself uses no Android 13+ APIs. The adaptive icon XML is
        // placed under mipmap-anydpi-v26/ so pre-Oreo devices fall back
        // to the WebP icons in mipmap-{m,h,xh,xxh,xxxh}dpi/.
        minSdk = 24
        targetSdk = 36
        versionCode = 10
        versionName = "1.8"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        ndk {
            abiFilters.add("arm64-v8a")
        }

        externalNativeBuild {
            cmake {
                arguments += "-DCMAKE_BUILD_TYPE=Release"
                arguments += "-DBUILD_SHARED_LIBS=ON"
                arguments += "-DLLAMA_BUILD_COMMON=ON"
                arguments += "-DLLAMA_OPENSSL=OFF"

                arguments += "-DGGML_NATIVE=OFF"
                arguments += "-DGGML_LLAMAFILE=ON"
                arguments += "-DGGML_CPU_ARM_ARCH=armv8.6-a+dotprod+i8mm+fp16+bf16"
            }
        }
    }

    // Release signing config. Credentials live in ~/.gradle/gradle.properties
    // (outside any git repo, only readable by your local mac account).
    // If those properties aren't set the release build still works but produces
    // an unsigned apk - useful e.g. on CI without secrets.
    signingConfigs {
        create("release") {
            val keystorePath = providers.gradleProperty("MINICPMV_KEYSTORE").orNull
            if (!keystorePath.isNullOrBlank()) {
                storeFile = file(keystorePath)
                storePassword = providers.gradleProperty("MINICPMV_KEYSTORE_PASSWORD").orNull
                keyAlias = providers.gradleProperty("MINICPMV_KEY_ALIAS").orNull
                keyPassword = providers.gradleProperty("MINICPMV_KEY_PASSWORD").orNull
            }
        }
    }

    buildTypes {
        release {
            // Keep ProGuard/R8 disabled: the app calls native JNI symbols and
            // shrinking the Kotlin side has no measurable benefit here, while
            // an over-aggressive shrinker is the most common cause of crashes
            // in apps with lots of JNI bindings.
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Only attach the signing config when the keystore actually exists,
            // so contributors without the secret can still run :assembleRelease
            // (it'll produce an unsigned apk in that case).
            val signingCfg = signingConfigs.getByName("release")
            if (signingCfg.storeFile?.exists() == true) {
                signingConfig = signingCfg
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
    buildFeatures {
        viewBinding = true
    }

    androidResources {
        noCompress.add("gguf")
        noCompress.add("bin")
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.androidx.constraintlayout)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.ktx)
    implementation(libs.androidx.activity.ktx)
    implementation("androidx.coordinatorlayout:coordinatorlayout:1.2.0")
    implementation("androidx.recyclerview:recyclerview:1.3.2")

    // Markdown rendering for AI streaming responses (headings, bold, lists, code, etc.)
    implementation("io.noties.markwon:core:4.6.2")
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
}
