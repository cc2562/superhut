// 插件版本统一在 settings.gradle.kts 的 plugins 块里声明。
// 这里不要再加 buildscript classpath：重复声明会让旧版本先进入 classpath，
// 实际生效版本与 settings 不一致（历史包袱：AGP 8.12.3 + Kotlin 1.9.0）。

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

// qr_code_scanner 仍在 build.gradle 里写死 compileSdkVersion 33，而它传递依赖的
// androidx.fragment 1.7.1 要求 34+；AGP 9 的 AAR metadata 校验会因此直接失败。
// 插件从 git 拉取、位于 pub 缓存中无法直接改，这里在子项目评估后强制拉到 36。
// 必须注册在 evaluationDependsOn 之前，否则子项目已被评估、afterEvaluate 会报错。
subprojects {
    if (name == "qr_code_scanner") {
        afterEvaluate {
            extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)
                ?.compileSdk = 36
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
