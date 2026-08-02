package to.bullet.device_calendar_plus_android

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat

// Shared permission gates for the service classes. Android has no single
// "calendar permission": READ_CALENDAR alone is enough to read, WRITE_CALENDAR
// alone is the write-only tier, and the full tier means holding both — the
// same mapping PermissionService reports to Dart.

/**
 * Gate for read endpoints. A denied read can surface as either a thrown
 * SecurityException or a silently empty cursor, and only an explicit check
 * distinguishes "can't read" from "genuinely nothing there" — without it a
 * denied app sees an empty result where iOS deterministically throws.
 */
internal fun readAccessFailure(context: Context): CalendarException? {
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALENDAR)
        != PackageManager.PERMISSION_GRANTED) {
        return CalendarException(
            PlatformExceptionCodes.PERMISSION_DENIED,
            "Calendar permission denied. Call requestPermissions() first."
        )
    }
    return null
}

/**
 * Gate for operations that need the full tier — write-only covers only
 * createEvent, per doc/permissions.md. The message names the tier because a
 * plain "call requestPermissions()" is a no-op for a write-only holder: their
 * request already succeeded, at the wrong level.
 */
internal fun fullAccessFailure(context: Context): CalendarException? {
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_CALENDAR)
        != PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALENDAR)
        != PackageManager.PERMISSION_GRANTED) {
        return CalendarException(
            PlatformExceptionCodes.PERMISSION_DENIED,
            "Calendar permission denied. Full access is required — call " +
                "requestPermissions(level: CalendarAccessLevel.full) first."
        )
    }
    return null
}
