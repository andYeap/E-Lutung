# Aturan R8 untuk build release.

# Plugin google_mlkit_text_recognition merujuk skrip selain Latin (Chinese,
# Devanagari, Japanese, Korean) yang tidak ikut dibundel karena aplikasi hanya
# memakai Latin. Abaikan peringatan kelas yang hilang itu.
-dontwarn com.google.mlkit.**
-keep class com.google.mlkit.** { *; }
