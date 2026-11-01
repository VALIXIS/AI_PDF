# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-dontwarn io.flutter.embedding.**

# Syncfusion PDF & PDF Native Libraries
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# Hive Flutter Storage
-keep class com.hive.** { *; }
-dontwarn com.hive.**

# AndroidX Core & FileProvider
-keep class androidx.core.content.FileProvider { *; }
-dontwarn androidx.core.content.FileProvider

# Share Plus Plugin
-keep class io.flutter.plugins.share.** { *; }
-dontwarn io.flutter.plugins.share.**

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Keep generated plugin registrants
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
