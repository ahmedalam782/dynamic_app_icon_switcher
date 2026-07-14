import 'dart:convert';

import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher.dart';

/// Fetches icon + splash brand config from **your backend API**.
///
/// Replace [fetchBrandConfig] with a real HTTP call, e.g.:
/// ```dart
/// final res = await http.get(Uri.parse('https://api.example.com/branding'));
/// return RemoteBrandConfig.parse(
///   jsonDecode(res.body) as Map<String, dynamic>,
/// );
/// ```
///
/// No Firebase / Firestore / Remote Config required.
class BrandConfigApi {
  /// Demo endpoint simulation (same payload your API would return).
  static Future<RemoteBrandConfig> fetchBrandConfig() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // Pretend this string arrived from: GET /api/branding
    //
    // To enable a CDN splash (ImageKit / S3 / etc.), set:
    //   "use_default_splash": false,
    //   "image_url": "https://ik.imagekit.io/.../splash.webp",
    //   "image_version": "4"
    const String apiResponseBody = '''
{
  "app_icon": {
    "enabled": true,
    "active_icon": "Ramadan",
    "icon_version": "3",
    "available_icons": ["Ramadan", "EidAdha", "Red", "Blue", "Green", "WorldCup"],
    "icon_schedule": [
      { "icon": "Ramadan", "from": "2026-02-01", "to": "2026-03-31" },
      { "icon": "EidAdha", "from": "2026-05-01", "to": "2026-06-30" },
      { "icon": "WorldCup", "from": "2026-06-01", "to": "2026-07-31" },
      { "icon": "Green", "from": "2026-07-01", "to": "2026-07-20" },
      { "icon": "Red", "from": "2026-01-01", "to": "2026-06-30" },
      { "icon": "Blue", "from": "2026-08-01", "to": "2026-12-31" }
    ]
  },
  "splash": {
    "use_default_splash": true,
    "image_url": "",
    "image_version": "1"
  }
}
''';

    final decoded = jsonDecode(apiResponseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Brand config API must return a JSON object');
    }
    return RemoteBrandConfig.parse(decoded);
  }
}
