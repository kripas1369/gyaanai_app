# Added to fix R8 "Missing class com.google.mediapipe.proto.*" errors for MediaPipe.
# Safe to keep for release builds.

-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate
