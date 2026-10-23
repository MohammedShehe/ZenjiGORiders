allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


// Keep the Google Places SDK on the last 4.x line.
// flutter_google_places_sdk_android 0.2.2 uses Place fields removed in Places SDK 5.0.0.
subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.google.android.libraries.places" &&
                requested.name == "places") {
                useVersion("4.4.1")
                because("The current flutter_google_places_sdk_android plugin is incompatible with Places SDK 5.x")
            }
        }
    }
}
