import org.gradle.api.tasks.Sync

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val pluginName = "SnapParAndroid"
val pluginPackageName = "ch.snappar.android"

android {
    namespace = pluginPackageName
    compileSdk = 34

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = pluginName
        manifestPlaceholders["godotPluginPackageName"] = pluginPackageName
        buildConfigField("String", "GODOT_PLUGIN_NAME", "\"$pluginName\"")
        setProperty("archivesBaseName", pluginName)
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("org.godotengine:godot:4.3.0.stable")
    implementation("androidx.core:core:1.13.1")
}

tasks.register<Sync>("packagePlugin") {
    dependsOn("assembleDebug", "assembleRelease")
    into(rootProject.file("addons/$pluginName"))
    from("export_scripts_template")
    from(layout.buildDirectory.file("outputs/aar/$pluginName-debug.aar")) {
        into("bin/debug")
    }
    from(layout.buildDirectory.file("outputs/aar/$pluginName-release.aar")) {
        into("bin/release")
    }
}
