-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# shared_preferences_android / path_provider_android 使用 Pigeon JNI，
# 运行时按类名和原始签名（kotlin/coroutines/Continuation、kotlin/Result 等）查找 Kotlin 类/方法。
# R8 混淆这些类名后 release 包会抛 NoSuchMethodError / ClassNotFoundException，进而卡在启动页。
-keep class kotlin.** { *; }
-keep class androidx.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.facebook.** { *; }
-dontwarn io.flutter.**
-dontwarn androidx.**
