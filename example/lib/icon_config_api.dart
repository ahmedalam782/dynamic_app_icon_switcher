import 'dart:convert';

/// Fetches icon availability from your backend / Firebase Remote Config.
///
/// Replace [fetchIconConfig] body with a real HTTP call, e.g.:
/// ```dart
/// final res = await http.get(Uri.parse('https://api.example.com/app-icons'));
/// return jsonDecode(res.body) as Map<String, dynamic>;
/// ```
///
/// Expected JSON shape:
/// ```json
/// {
///   "available_icons": ["Red", "Blue", "Green", "WorldCup"],
///   "icon_schedule": [
///     { "icon": "WorldCup", "from": "2026-06-01", "to": "2026-07-31" }
///   ]
/// }
/// ```
class IconConfigApi {
  /// Demo endpoint simulation (same payload your API would return).
  ///
  /// In production this comes from the network — never hardcode the picker
  /// list in UI widgets.
  static Future<Map<String, dynamic>> fetchIconConfig() async {
    // Simulate network latency.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // Pretend this string arrived from: GET /api/app-icons
    const String apiResponseBody = '''
{
  "available_icons": ["Red", "Blue", "Green", "WorldCup"],
  "icon_schedule": [
    { "icon": "WorldCup", "from": "2026-06-01", "to": "2026-07-31" },
    { "icon": "Green", "from": "2026-07-01", "to": "2026-07-20" },
    { "icon": "Red", "from": "2026-01-01", "to": "2026-06-30" },
    { "icon": "Blue", "from": "2026-08-01", "to": "2026-12-31" }
  ]
}
''';

    final decoded = jsonDecode(apiResponseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Icon config API must return a JSON object');
    }
    return decoded;
  }
}
