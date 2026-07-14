import 'icon_availability.dart';

/// Remote brand config delivered by **your HTTP API** (not Firebase).
///
/// Typical response:
/// ```json
/// {
///   "app_icon": {
///     "enabled": true,
///     "active_icon": "ramadan",
///     "icon_version": "2",
///     "available_icons": ["ramadan", "eid_adha", "WorldCup"],
///     "icon_schedule": [
///       { "icon": "WorldCup", "from": "2026-06-01", "to": "2026-07-31" }
///     ]
///   },
///   "splash": {
///     "use_default_splash": false,
///     "image_url": "https://cdn.example.com/ramadan-splash.webp",
///     "image_version": "4"
///   }
/// }
/// ```
///
/// Launcher icons must already ship in the binary. The API only selects which
/// pre-bundled key is active. Splash images *may* come from a CDN URL.
class RemoteBrandConfig {
  /// Creates a parsed brand config.
  const RemoteBrandConfig({
    required this.appIcon,
    required this.splash,
  });

  /// Launcher-icon remote settings.
  final RemoteAppIconConfig appIcon;

  /// In-app splash remote settings.
  final RemoteSplashConfig splash;

  /// Parses a top-level API JSON object.
  ///
  /// Accepts either nested `app_icon` / `splash` objects, or a flat map that
  /// only describes icons (legacy picker API).
  factory RemoteBrandConfig.parse(Map<String, dynamic> json) {
    final iconRaw = json['app_icon'];
    final splashRaw = json['splash'];

    final RemoteAppIconConfig appIcon;
    if (iconRaw is Map) {
      appIcon = RemoteAppIconConfig.parse(Map<String, dynamic>.from(iconRaw));
    } else {
      appIcon = RemoteAppIconConfig.parse(json);
    }

    final RemoteSplashConfig splash;
    if (splashRaw is Map) {
      splash = RemoteSplashConfig.parse(Map<String, dynamic>.from(splashRaw));
    } else {
      splash = const RemoteSplashConfig(
        useDefaultSplash: true,
        imageUrl: '',
        imageVersion: '',
      );
    }

    return RemoteBrandConfig(appIcon: appIcon, splash: splash);
  }
}

/// API-controlled launcher icon selection.
class RemoteAppIconConfig {
  /// Creates icon remote settings.
  const RemoteAppIconConfig({
    this.enabled = true,
    this.activeIcon = 'default',
    this.iconVersion = '',
    this.availableIcons = const <String>[],
    this.schedule = const <IconScheduleEntry>[],
  });

  /// When `false`, the client should leave the launcher icon alone.
  final bool enabled;

  /// Pre-bundled icon key to apply (e.g. `ramadan`). Use `default` for primary.
  final String activeIcon;

  /// Bump on the server when [activeIcon] should be re-applied on devices.
  final String iconVersion;

  /// Optional allow-list for a manual picker UI.
  final List<String> availableIcons;

  /// Optional date windows for picker visibility.
  final List<IconScheduleEntry> schedule;

  /// Parses an `app_icon` object or a flat legacy icon JSON map.
  factory RemoteAppIconConfig.parse(Map<String, dynamic> json) {
    final availability = IconAvailability.parseConfig(json);
    final active = (json['active_icon'] ?? json['activeIcon'] ?? 'default')
        .toString()
        .trim();
    final version =
        (json['icon_version'] ?? json['iconVersion'] ?? '').toString().trim();
    final enabledRaw = json['enabled'];
    final enabled = enabledRaw is bool
        ? enabledRaw
        : enabledRaw == null
            ? true
            : enabledRaw.toString().toLowerCase() != 'false';

    return RemoteAppIconConfig(
      enabled: enabled,
      activeIcon: active.isEmpty ? 'default' : active,
      iconVersion: version,
      availableIcons: availability.availableIcons,
      schedule: availability.schedule,
    );
  }

  /// Whether the client should call native `setIcon` for this payload.
  ///
  /// Skips when disabled, unsupported key, or same icon+version already applied.
  bool shouldApply({
    required Set<String> shippedIcons,
    required String? lastAppliedIcon,
    required String? lastAppliedVersion,
  }) {
    if (!enabled) {
      return false;
    }

    final target = activeIcon.trim().isEmpty ? 'default' : activeIcon.trim();
    if (target != 'default' && !shippedIcons.contains(target)) {
      return false;
    }

    if (lastAppliedIcon == target && lastAppliedVersion == iconVersion) {
      return false;
    }

    return true;
  }

  /// Resolved native icon name to pass to [DynamicAppIconSwitcher.setIcon].
  String get targetIconName {
    final target = activeIcon.trim();
    return target.isEmpty ? 'default' : target;
  }
}

/// API-controlled in-app splash image (CDN URL — not the OS launch screen).
class RemoteSplashConfig {
  /// Creates splash remote settings.
  const RemoteSplashConfig({
    required this.useDefaultSplash,
    required this.imageUrl,
    required this.imageVersion,
  });

  /// When `true`, the app should use its built-in / last-default splash UI.
  final bool useDefaultSplash;

  /// CDN URL (ImageKit, S3, etc.). Empty when using default splash.
  final String imageUrl;

  /// Bump when the splash image changes so clients bust cache.
  final String imageVersion;

  /// Parses a `splash` object from the API.
  factory RemoteSplashConfig.parse(Map<String, dynamic> json) {
    final useDefaultRaw =
        json['use_default_splash'] ?? json['useDefaultSplash'] ?? true;
    final useDefault = useDefaultRaw is bool
        ? useDefaultRaw
        : useDefaultRaw.toString().toLowerCase() != 'false';
    final url =
        (json['image_url'] ?? json['imageUrl'] ?? '').toString().trim();
    final version =
        (json['image_version'] ?? json['imageVersion'] ?? '').toString().trim();

    return RemoteSplashConfig(
      useDefaultSplash: useDefault,
      imageUrl: url,
      imageVersion: version,
    );
  }

  /// URL with `splash_version` query param for cache busting when version set.
  String? get cacheBustedUrl {
    if (useDefaultSplash || imageUrl.isEmpty) {
      return null;
    }
    if (imageVersion.isEmpty) {
      return imageUrl;
    }
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasScheme) {
      return imageUrl;
    }
    final params = Map<String, String>.from(uri.queryParameters);
    params['splash_version'] = imageVersion;
    return uri.replace(queryParameters: params).toString();
  }

  /// Whether a remote splash image should be shown / precached.
  bool get hasRemoteImage =>
      !useDefaultSplash && imageUrl.isNotEmpty;
}
