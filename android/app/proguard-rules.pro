# Flutter-specific rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Keep JNI entry points for Rust FFI (flutter_rust_bridge)
-keep class com.fomowl.owllet.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# local_auth / biometrics
-keep class androidx.biometric.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Kotlin coroutines / serialization
-keepnames class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# OkHttp (used under the hood by http/dio)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Prevent stripping of crypto JNI symbols
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Preserve stack traces for crash reporting
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
