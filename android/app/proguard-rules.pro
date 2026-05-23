# ML Kit Text Recognition - Keep all text recognizer classes
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# Keep ML Kit common classes
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Stripe SDK - Keep all Stripe classes
-keep class com.stripe.android.** { *; }
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.stripe.android.**

# React Native Stripe SDK (used by flutter_stripe internally)
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.reactnativestripesdk.**

# Keep all classes that might be referenced by Stripe
-keepclassmembers class * {
    @com.stripe.android.** *;
}
