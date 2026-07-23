import 'dart:ui' show Color;

/// Parses a hex color string into a [Color].
///
/// Accepts `#RRGGBB` or `#AARRGGBB` (the `#` prefix is optional). 6-digit
/// values are treated as fully opaque; 8-digit values keep their own alpha.
/// Returns `null` when [hex] is `null` or unparseable.
///
/// Package-internal: shared by `Calendar.color` and `Event.color`.
Color? colorFromHex(String? hex) {
  if (hex == null) return null;
  final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(cleaned.length == 6 ? value | 0xFF000000 : value);
}
