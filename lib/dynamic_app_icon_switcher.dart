import 'package:flutter/services.dart';

import 'dynamic_app_icon_switcher_platform_interface.dart';
import 'src/icon_availability.dart';
import 'src/remote_brand_config.dart';

export 'src/icon_availability.dart';
export 'src/remote_brand_config.dart';

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
  /// optional API availability / schedule data.
  ///
  /// Pass either a full brand payload (`app_icon` nested) or a flat legacy
  /// `{ available_icons, icon_schedule }` map. Only icons that exist on the
  /// device are returned.
  Future<List<String>> resolvePickerIcons({
    Map<String, dynamic>? remoteConfig,
    DateTime? now,
  }) async {
    final shipped = await getAvailableIcons();
    if (remoteConfig == null) {
      return IconAvailability.resolveAvailable(shippedIcons: shipped);
    }
    final brand = RemoteBrandConfig.parse(remoteConfig);
    final config = brand.appIcon;
    final available = config.availableIcons.isEmpty
        ? null
        : config.availableIcons;
    return IconAvailability.resolveAvailable(
      shippedIcons: shipped,
      availableFromRemote: available,
      schedule: config.schedule,
      now: now,
    );
  }

  /// Applies [config.activeIcon] when the API version / key changed.
  ///
  /// Persisting [lastAppliedIcon] / [lastAppliedVersion] is the app's job
  /// (e.g. `shared_preferences`). Returns the icon that was set, or `null`
  /// when no native switch was needed.
  Future<String?> applyActiveIconIfNeeded({
    required RemoteAppIconConfig config,
    required String? lastAppliedIcon,
    required String? lastAppliedVersion,
  }) async {
    final shipped = (await getAvailableIcons()).toSet();
    if (!config.shouldApply(
      shippedIcons: shipped,
      lastAppliedIcon: lastAppliedIcon,
      lastAppliedVersion: lastAppliedVersion,
    )) {
      return null;
    }

    final target = config.targetIconName;
    await setIcon(target);
    return target;
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
