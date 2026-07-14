/// In-memory demo backend so the example can simulate an **admin** changing
/// `active_icon` anytime without rebuilding the app.
///
/// Production apps replace this with a real HTTP API; the client still only
/// needs `GET /branding` (and optionally a refresh interval / push).
class DemoBrandStore {
  DemoBrandStore._();

  static final DemoBrandStore instance = DemoBrandStore._();

  /// Current branding JSON returned by the demo `GET /branding` interceptor.
  Map<String, dynamic> payload = _initialPayload();

  /// Resets to the default demo branding (Ramadan).
  void reset() {
    payload = _initialPayload();
  }

  /// Simulates an admin updating the active launcher icon on the server.
  ///
  /// Bumps [icon_version] so clients re-apply even if they already used this
  /// key earlier in the session. Icon names must already be **shipped** in the
  /// app binary (`setIcon` only works for pre-bundled keys).
  void setActiveIcon(String iconName, {bool enabled = true}) {
    final appIcon = Map<String, dynamic>.from(
      payload['app_icon'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final previous = (appIcon['icon_version'] ?? '0').toString();
    final nextVersion = (int.tryParse(previous) ?? 0) + 1;

    appIcon['enabled'] = enabled;
    appIcon['active_icon'] = iconName;
    appIcon['icon_version'] = '$nextVersion';
    payload = <String, dynamic>{
      ...payload,
      'app_icon': appIcon,
    };
  }

  static Map<String, dynamic> _initialPayload() => <String, dynamic>{
        'app_icon': <String, dynamic>{
          'enabled': true,
          'active_icon': 'Ramadan',
          'icon_version': '3',
          'available_icons': <String>[
            'Ramadan',
            'EidAdha',
            'Red',
            'Blue',
            'Green',
            'WorldCup',
            'Promo',
          ],
          // Empty schedule = all available_icons may appear in the picker.
          // Add date windows when you want seasonal picker filtering.
          'icon_schedule': <Map<String, String>>[],
        },
        'splash': <String, dynamic>{
          'use_default_splash': true,
          'image_url': '',
          'image_version': '1',
        },
      };
}
