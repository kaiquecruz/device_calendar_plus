package to.bullet.example

import android.content.ContentUris
import android.content.ContentValues
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Test-only channel used by the integration tests to seed calendar
        // provider state the plugin deliberately can't write itself.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "to.bullet.device_calendar_plus_example/test"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // EVENT_COLOR is sync-adapter-owned, so stamp it the way a
                // sync adapter would: a CALLER_IS_SYNCADAPTER update scoped to
                // the plugin's local test account. This simulates an external
                // app (e.g. Google Calendar) assigning a custom event color.
                "setEventColor" -> {
                    try {
                        val eventId = call.argument<String>("eventId")!!.toLong()
                        val color = call.argument<Number>("color")!!.toInt()
                        val uri = ContentUris
                            .withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)
                            .buildUpon()
                            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
                            // Plugin-created local calendars use account name
                            // "local" with ACCOUNT_TYPE_LOCAL (see the plugin's
                            // CalendarService.createCalendar).
                            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, "local")
                            .appendQueryParameter(
                                CalendarContract.Calendars.ACCOUNT_TYPE,
                                CalendarContract.ACCOUNT_TYPE_LOCAL
                            )
                            .build()
                        val values = ContentValues().apply {
                            put(CalendarContract.Events.EVENT_COLOR, color)
                        }
                        val updated = contentResolver.update(uri, values, null, null)
                        result.success(updated)
                    } catch (e: Exception) {
                        result.error("TEST_SEED_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
