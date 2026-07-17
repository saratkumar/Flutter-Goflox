allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // play-services-tapandpay is gated behind Google's Tap-and-Pay partner
    // approval and isn't published to a public Maven repo. It's only a
    // transitive dependency of Stripe's optional card-issuing/push
    // provisioning module, which this app doesn't use — exclude just that
    // one unresolvable artifact so Gradle doesn't try to fetch it, while
    // stripe-android-issuing-push-provisioning itself (whose classes
    // flutter_stripe compiles against) still resolves normally.
    configurations.all {
        exclude(group = "com.google.android.gms", module = "play-services-tapandpay")
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
