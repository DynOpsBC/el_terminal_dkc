-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod
-keep class kotlin.Metadata { *; }
-keep class kotlin.reflect.** { *; }
-dontwarn kotlin.reflect.**

# Ktor client, content negotiation, and kotlinx serialization.
-keep class io.ktor.** { *; }
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class **$$serializer { *; }
-keepclasseswithmembers class * {
    public static ** serializer(...);
}
-dontwarn io.ktor.**

# Room entities, DAOs, and generated database implementations.
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao class * { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class **_Impl { *; }
-dontwarn androidx.room.**

# Microsoft Authentication Library.
-keep class com.microsoft.identity.** { *; }
-keep class com.microsoft.aad.** { *; }
-dontwarn com.microsoft.identity.**

# Hilt and Dagger generated classes.
-keep class dagger.hilt.** { *; }
-keep class hilt_aggregated_deps.** { *; }
-keep class *_HiltModules_* { *; }
-keep class * extends dagger.hilt.android.internal.managers.** { *; }
-dontwarn dagger.hilt.**

# Firebase, Crashlytics, Performance, and Messaging.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
