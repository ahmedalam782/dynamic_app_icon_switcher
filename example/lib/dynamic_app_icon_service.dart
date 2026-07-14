import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Applies the API-selected launcher icon and remembers the last success.
///
/// Mirrors the article's DynamicAppIconService, but reads from your HTTP API
/// instead of Firestore.
class DynamicAppIconService {
  DynamicAppIconService({
    DynamicAppIconSwitcher? plugin,
    SharedPreferences? prefs,
  })  : _plugin = plugin ?? DynamicAppIconSwitcher(),
        _prefsOverride = prefs;

  static const _keyIcon = 'applied_active_icon';
  static const _keyVersion = 'applied_icon_version';

  final DynamicAppIconSwitcher _plugin;
  final SharedPreferences? _prefsOverride;

  Future<SharedPreferences> get _prefs async =>
      _prefsOverride ?? SharedPreferences.getInstance();

  /// Reads Firestore-equivalent fields from [config] and switches the native
  /// icon only when needed.
  Future<ApplyIconResult> applyFromConfig(RemoteAppIconConfig config) async {
    final prefs = await _prefs;
    final lastIcon = prefs.getString(_keyIcon);
    final lastVersion = prefs.getString(_keyVersion);

    if (!config.enabled) {
      return const ApplyIconResult(
        skipped: true,
        reason: 'Icon switching disabled by API',
      );
    }

    final shipped = (await _plugin.getAvailableIcons()).toSet();
    final target = config.targetIconName;
    if (target != 'default' && !shipped.contains(target)) {
      return ApplyIconResult(
        skipped: true,
        reason: 'Unsupported icon key: $target',
      );
    }

    final applied = await _plugin.applyActiveIconIfNeeded(
      config: config,
      lastAppliedIcon: lastIcon,
      lastAppliedVersion: lastVersion,
    );

    if (applied == null) {
      return ApplyIconResult(
        skipped: true,
        reason: 'Already on $target (version ${config.iconVersion})',
        iconName: lastIcon ?? await _plugin.currentIcon(),
      );
    }

    await prefs.setString(_keyIcon, applied);
    await prefs.setString(_keyVersion, config.iconVersion);

    return ApplyIconResult(
      skipped: false,
      reason: 'Applied $applied (version ${config.iconVersion})',
      iconName: applied,
    );
  }

  Future<String> currentIcon() => _plugin.currentIcon();

  Future<List<String>> getAvailableIcons() => _plugin.getAvailableIcons();

  Future<bool> supportsAlternateIcons() => _plugin.supportsAlternateIcons();

  Future<List<String>> resolvePickerIcons({
    required RemoteAppIconConfig config,
    DateTime? now,
  }) {
    return _plugin.resolvePickerIcons(
      remoteConfig: <String, dynamic>{
        'available_icons': config.availableIcons,
        'icon_schedule': config.schedule
            .map(
              (e) => <String, String?>{
                'icon': e.icon,
                'from': e.from?.toIso8601String().split('T').first,
                'to': e.to?.toIso8601String().split('T').first,
              },
            )
            .toList(),
      },
      now: now,
    );
  }

  Future<void> setIcon(String name) => _plugin.setIcon(name);
}

/// Outcome of [DynamicAppIconService.applyFromConfig].
class ApplyIconResult {
  const ApplyIconResult({
    required this.skipped,
    required this.reason,
    this.iconName,
  });

  final bool skipped;
  final String reason;
  final String? iconName;
}
