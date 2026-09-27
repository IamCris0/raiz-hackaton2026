# El plugin de ML Kit referencia los reconocedores de chino, japonés, coreano
# y devanagari aunque solo usamos el latino; sin esto R8 falla en release.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
