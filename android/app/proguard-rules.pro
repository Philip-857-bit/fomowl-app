# Flutter and modern plugins publish their own consumer keep rules. Keeping
# every engine/plugin class here prevents R8 from shrinking or obfuscating
# unused code and is the reason Play reports a low optimization rate.
-dontwarn io.flutter.**

# Keep only methods whose names are resolved dynamically by JNI.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# These libraries ship consumer rules; warnings for optional platform classes
# do not require retaining their entire dependency graphs.
-dontwarn com.google.firebase.**
-dontwarn kotlinx.coroutines.**
-dontwarn okhttp3.**
-dontwarn okio.**

# JavaScript interface methods are invoked by Android WebView via reflection.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Preserve stack traces for crash reporting
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
