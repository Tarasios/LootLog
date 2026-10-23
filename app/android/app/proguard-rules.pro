# Ignore missing classes for unused ML Kit Text Recognition language models
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit (barcode scanning for hub pairing, text recognition for receipts)
# discovers its ComponentRegistrar classes by name from manifest meta-data and
# instantiates them reflectively. Nothing calls those constructors directly, so
# R8 strips them; ML Kit then skips the registrar and BarcodeScanning.getClient
# fails with a NullPointerException on its (unregistered) scanner factory.
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
