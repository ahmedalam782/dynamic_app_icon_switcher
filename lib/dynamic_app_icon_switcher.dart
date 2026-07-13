import 'package:flutter/services.dart';

import 'dynamic_app_icon_switcher_platform_interface.dart';
import 'src/icon_availability.dart';

export 'src/icon_availability.dart';

/// Error codes returned via [PlatformException.code].
abstract final class DynamicAppIconSwitcherErrorCodes {
  /// The current platform does not support alternate icons.
  static const String platformNotSupported = 'PLATFORM_NOT_SUPPORTED';

  /// The requested icon name is not declared natively.
  static const String iconNotFound = 'ICON_NOT_FOUND';

  /// The platform failed to apply the icon change.
  static const String setIconFailed = 'SET_ICON_FAILED';
}

/// Flutter plugin for switching the app's launcher / home-screen icon at
/// runtime on Android and iOS.
///
/// Android uses `activity-alias` entries whose names contain `.icons.`.
/// iOS uses `CFBundleAlternateIcons` in `Info.plist`.
class DynamicAppIconSwitcher {
  /// Whether alternate icons are supported on this device.
  Future<bool> supportsAlternateIcons() {
    return DynamicAppIconSwitcherPlatform.instance.supportsAlternateIcons();
  }

  /// Changes the launcher icon to [iconName].
  ///
  /// Use `'default'` to restore the primary icon.
  ///
  /// Throws [PlatformException] with:
  /// - [DynamicAppIconSwitcherErrorCodes.iconNotFound]
  /// - [DynamicAppIconSwitcherErrorCodes.setIconFailed]
  /// - [DynamicAppIconSwitcherErrorCodes.platformNotSupported]
  Future<void> setIcon(String iconName) {
    return DynamicAppIconSwitcherPlatform.instance.setIcon(iconName);
  }

  /// The active icon name, or `'default'` for the primary icon.
  Future<String> currentIcon() {
    return DynamicAppIconSwitcherPlatform.instance.currentIcon();
  }

  /// Alternate icon names declared in the native binary (excludes `default`).
  Future<List<String>> getAvailableIcons() {
    return DynamicAppIconSwitcherPlatform.instance.getAvailableIcons();
  }

  /// Builds the picker list from natively shipped icons intersected with
  /// optional remote availability / schedule data.
  ///
  /// Does **not** hardcode icon names — callers supply Remote Config (or any
  /// JSON map) and this method filters against what the OS can actually set.
  Future<List<String>> resolvePickerIcons({
    Map<String, dynamic>? remoteConfig,
    DateTime? now,
  }) async {
    final shipped = await getAvailableIcons();
    if (remoteConfig == null) {
      return IconAvailability.resolveAvailable(shippedIcons: shipped);
    }
    final config = IconAvailability.parseConfig(remoteConfig);
    return IconAvailability.resolveAvailable(
      shippedIcons: shipped,
      availableFromRemote: config.availableIcons,
      schedule: config.schedule,
      now: now,
    );
  }

  /// If [current] is no longer in [visibleIcons], returns `'default'`.
  String fallbackIfUnavailable({
    required String current,
    required List<String> visibleIcons,
  }) {
    return IconAvailability.fallbackIfUnavailable(
      currentIcon: current,
      visibleIcons: visibleIcons,
    );
  }
}
