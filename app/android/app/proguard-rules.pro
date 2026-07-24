# R8 rules for the release build.
#
# IMPORTANT: do NOT add -keep rules for io.flutter.** classes. R8 must be free to tree-shake
# the unused Flutter deferred-components embedding classes (PlayStoreDeferredComponentManager,
# FlutterPlayStoreSplitApplication) whose references to Google Play Core would otherwise trip
# F-Droid's APK scanner. See https://gitlab.com/fdroid/fdroiddata/-/issues/2949
#
# Play Core classes are referenced by that (stripped) Flutter code but never present; silence
# R8's missing-class warnings for them.
-dontwarn com.google.android.play.core.**
