# Flutter ProGuard / R8 Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# WorkManager & AndroidX Startup
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class androidx.work.** { *; }
-keep class androidx.startup.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * extends androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
    public *;
}

# AndroidX Room
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class * extends androidx.room.EntityDeletionOrUpdateAdapter { *; }
-keep class * extends androidx.room.EntityInsertionAdapter { *; }
-keep class * extends androidx.room.SharedSQLiteStatement { *; }
-dontwarn androidx.room.paging.**

# Drift / SQLite Keep Rules
-keep class * extends com.simolus3.drift.** { *; }
-keep class org.sqlite.** { *; }
-keep class io.requery.android.database.sqlite.** { *; }

# Google Sign-In & Auth
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Flutter Secure Storage / AndroidX Security Crypto
-keep class androidx.security.crypto.** { *; }

# Flutter Engine / JNI
-keepclassmembers class * {
    native <methods>;
}

# Flutter Deferred Components / Play Core (not used, safe to ignore)
-dontwarn com.google.android.play.core.**

# Suppress harmless warnings and keep attributes
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses,SourceFile,LineNumberTable
