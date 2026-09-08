/// Readers for the API's JSON, written around the shapes it actually returns.
///
/// Three conventions matter and are handled here rather than at every call
/// site: most optional fields are *absent* rather than null, travel segments
/// send real nulls, and `Day.date` / `Activity.time` use an empty string to
/// mean "not set".
class Json {
  const Json._();

  static Map<String, dynamic> asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> asMapList(Object? value) => value is List
      ? value.whereType<Map>().map(asMap).toList(growable: false)
      : const <Map<String, dynamic>>[];

  /// Null for an absent, null, or empty-string value — the API uses all three
  /// for "nothing here" depending on the field.
  static String? string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    final text = value is String ? value : '$value';
    return text.isEmpty ? null : text;
  }

  static String requiredString(
    Map<String, dynamic> json,
    String key, {
    String fallback = '',
  }) =>
      string(json, key) ?? fallback;

  static int? integer(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool boolean(
    Map<String, dynamic> json,
    String key, {
    bool fallback = false,
  }) {
    final value = json[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  static List<String> stringList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) return const <String>[];
    return value
        .where((entry) => entry != null)
        .map((entry) => '$entry')
        .toList(growable: false);
  }

  /// An ISO 8601 timestamp (`createdAt`, `publishedAt`, `calculatedAt`, ...).
  static DateTime? timestamp(Map<String, dynamic> json, String key) {
    final raw = string(json, key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// A `YYYY-MM-DD` calendar date. Empty strings — which `Day.date` uses for
  /// a trip without fixed dates — read as null.
  static DateTime? date(Map<String, dynamic> json, String key) {
    final raw = string(json, key);
    if (raw == null) return null;
    return DateTime.tryParse(raw.length > 10 ? raw.substring(0, 10) : raw);
  }

  /// `HH:mm` as returned; empty strings read as null.
  static String? time(Map<String, dynamic> json, String key) =>
      string(json, key);

  /// Formats a date the way every date field on the API expects it.
  static String formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  /// Formats a time of day as `HH:mm`.
  static String formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Drops null entries from a request body.
  ///
  /// `forbidNonWhitelisted` is on server-side, so a body must carry only keys
  /// the DTO declares; an omitted key also means "leave this alone" on PATCH.
  /// Use [Patch] where a field needs to be *cleared* with an explicit null.
  static Map<String, dynamic> compact(Map<String, dynamic> body) {
    final result = <String, dynamic>{};
    body.forEach((key, value) {
      if (value == null) return;
      if (value is Patch) {
        if (value.isClear) {
          result[key] = null;
        } else {
          result[key] = value.rawValue;
        }
        return;
      }
      result[key] = value;
    });
    return result;
  }
}

/// A field on a PATCH body that can be set, or explicitly cleared.
///
/// The itinerary DTOs distinguish an absent key ("do not touch") from a null
/// value ("clear this"). Pass `null` for the former and [Patch.clear] for the
/// latter; [Json.compact] keeps both straight.
class Patch<T> {
  const Patch.value(T value)
      : rawValue = value,
        isClear = false;

  const Patch.clear()
      : rawValue = null,
        isClear = true;

  final Object? rawValue;
  final bool isClear;

  T? get value => rawValue as T?;
}
