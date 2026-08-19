allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// removed evaluationDependsOn(":app") to avoid configuring :app during root project configuration,
// which can fail if the Android NDK is not properly installed or configured.

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
