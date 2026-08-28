# Flutter ProGuard / R8 Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Drift / SQLite Keep Rules
-keep class * extends com.simolus3.drift.** { *; }

# Flutter Engine / JNI
-keepclassmembers class * {
    native <methods>;
}

# Flutter Deferred Components / Play Core (not used, safe to ignore)
-dontwarn com.google.android.play.core.**

# Suppress harmless warnings and keep attributes
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses,SourceFile,LineNumberTable
