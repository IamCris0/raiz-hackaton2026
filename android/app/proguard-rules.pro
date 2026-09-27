# El plugin de ML Kit referencia los reconocedores de chino, japonés, coreano
# y devanagari aunque solo usamos el latino; sin esto R8 falla en release.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit carga sus componentes por reflexión: si R8 los renombra o elimina,
# el OCR falla en release (NullPointerException al procesar la imagen).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_commons.** { *; }
