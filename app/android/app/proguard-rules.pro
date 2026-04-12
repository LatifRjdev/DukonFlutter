# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Dio / OkHttp
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# JSON serialization
-keepattributes *Annotation*

# Firebase (for Sprint 3)
-keep class com.google.firebase.** { *; }

# Mobile Scanner / ML Kit
-keep class com.google.mlkit.** { *; }

# Thermal printer
-keep class net.posprinter.** { *; }
