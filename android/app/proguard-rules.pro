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

# ========== 友盟统计SDK混淆规则 ==========
-keep class com.umeng.** {*;}
-keep class org.repackage.** {*;}
-keep class com.uyumao.** { *; }
-keepclassmembers class * {
   public <init> (org.json.JSONObject);
}

# ========== 友盟 U-APM 混淆规则 ==========
-keep class com.efs.** { *; }
-keep class com.uc.** { *; }
# U-APM 的网络分析模块会引用 OkHttp 拦截器；本工程是 Flutter，运行时没有
# OkHttp，这些引用在 R8 看来是缺失类。保留编译期忽略，避免 release 构建失败。
-dontwarn okhttp3.**
-dontwarn okio.**
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
