# Flutter / Android release hardening

# Keep Flutter classes (safe baseline)
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.engine.**

# Keep Firebase (avoid over-shrinking issues with dynamic loading)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep Google Play services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
