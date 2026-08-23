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

# Keep generated plugin registrants
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
