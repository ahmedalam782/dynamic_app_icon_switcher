import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches the last successful splash config from your API.
///
/// Startup flow:
/// 1. Paint immediately from local prefs (or default UI)
/// 2. Fetch API in the background
/// 3. Precache the image; only then persist the new config
/// 4. Next cold start shows the new splash reliably
class SplashCacheService {
  SplashCacheService({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const _keyUseDefault = 'splash_use_default';
  static const _keyUrl = 'splash_image_url';
  static const _keyVersion = 'splash_image_version';

  final SharedPreferences? _prefsOverride;

  Future<SharedPreferences> get _prefs async =>
      _prefsOverride ?? SharedPreferences.getInstance();

  /// Last successful splash, or default placeholder when none saved.
  Future<CachedSplash> loadCached() async {
    final prefs = await _prefs;
    final useDefault = prefs.getBool(_keyUseDefault) ?? true;
    final url = prefs.getString(_keyUrl) ?? '';
    final version = prefs.getString(_keyVersion) ?? '';

    return CachedSplash(
      useDefaultSplash: useDefault || url.isEmpty,
      imageUrl: url,
      imageVersion: version,
    );
  }

  /// Precaches [config]'s image (if any). Persists only after success.
  Future<CachedSplash> syncFromApi(
    RemoteSplashConfig config, {
    required BuildContext context,
  }) async {
    if (!config.hasRemoteImage) {
      final cached = CachedSplash(
        useDefaultSplash: true,
        imageUrl: '',
        imageVersion: config.imageVersion,
      );
      await _persist(cached);
      return cached;
    }

    final url = config.cacheBustedUrl!;
    try {
      await precacheImage(NetworkImage(url), context);
      final cached = CachedSplash(
        useDefaultSplash: false,
        imageUrl: url,
        imageVersion: config.imageVersion,
      );
      await _persist(cached);
      return cached;
    } catch (_) {
      // Keep previous successful splash — never block app open.
      return loadCached();
    }
  }

  Future<void> _persist(CachedSplash splash) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyUseDefault, splash.useDefaultSplash);
    await prefs.setString(_keyUrl, splash.imageUrl);
    await prefs.setString(_keyVersion, splash.imageVersion);
  }
}

/// Locally persisted splash state for instant first paint.
class CachedSplash {
  const CachedSplash({
    required this.useDefaultSplash,
    required this.imageUrl,
    required this.imageVersion,
  });

  final bool useDefaultSplash;
  final String imageUrl;
  final String imageVersion;

  bool get hasImage => !useDefaultSplash && imageUrl.isNotEmpty;
}
