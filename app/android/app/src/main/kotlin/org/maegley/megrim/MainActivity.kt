package org.maegley.megrim

import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: local_auth's BiometricPrompt needs a
// FragmentActivity (app lock, backlog #24).
class MainActivity : FlutterFragmentActivity() {
    private var shortcutChannel: MethodChannel? = null

    /// A "Log migraine" shortcut that launched the app, held until Flutter asks for it.
    private var pendingShortcut: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Hide in recent apps": FLAG_SECURE blanks the switcher thumbnail and blocks screenshots.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.maegley.megrim/window")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        if (call.arguments as? Boolean == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // App-icon shortcut (backlog #23 step 1). A cold start keeps the action until Flutter asks
        // for it; a shortcut used while the app is running is pushed straight to Flutter.
        pendingShortcut = takeShortcut(intent)
        shortcutChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.maegley.megrim/shortcut")
                .apply {
                    setMethodCallHandler { call, result ->
                        when (call.method) {
                            "initialAction" -> {
                                result.success(pendingShortcut)
                                pendingShortcut = null
                            }
                            else -> result.notImplemented()
                        }
                    }
                }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        takeShortcut(intent)?.let { shortcutChannel?.invokeMethod("action", it) }
    }

    /// The shortcut action carried by [intent], if any, then cleared from the activity's intent so
    /// that re-creating the activity, or reopening it from Recents (which replays the original
    /// launch intent), never logs a second migraine.
    private fun takeShortcut(intent: Intent?): String? {
        if (intent?.action != ACTION_LOG_MIGRAINE) return null
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        setIntent(Intent(intent).setAction(Intent.ACTION_MAIN))
        return "log_migraine"
    }

    private companion object {
        const val ACTION_LOG_MIGRAINE = "org.maegley.megrim.action.LOG_MIGRAINE"
    }
}
