# Flutter / Dart 엔진 — R8 난독화 시 보존
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# 플러그인(이미지 선택/공유 등)에서 쓰는 androidx 일부 보존
-keep class androidx.lifecycle.** { *; }

# 일반적으로 안전한 경고 무시
-dontwarn javax.annotation.**
