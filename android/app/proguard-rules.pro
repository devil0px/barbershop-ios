# Flutter rules are compiled into AARs, but apps may have their own dependencies.
# This rule prevents the R8 compiler from removing APIs that are used by the app.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.embedding.**  { *; }

# Fix for R8 Missing Class com.google.android.play.core
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-ignorewarnings
