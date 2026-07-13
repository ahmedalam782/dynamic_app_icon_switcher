import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dynamic_app_icon_switcher_method_channel.dart';

/// Platform interface for [DynamicAppIconSwitcher].
abstract class DynamicAppIconSwitcherPlatform extends PlatformInterface {
  /// Constructs a DynamicAppIconSwitcherPlatform.
  DynamicAppIconSwitcherPlatform() : super(token: _token);

  static final Object _token = Object();

  static DynamicAppIconSwitcherPlatform _instance =
      MethodChannelDynamicAppIconSwitcher();

  /// The default instance of [DynamicAppIconSwitcherPlatform] to use.
  ///
  /// Defaults to [MethodChannelDynamicAppIconSwitcher].
  static DynamicAppIconSwitcherPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DynamicAppIconSwitcherPlatform]
  /// when they register themselves.
  static set instance(DynamicAppIconSwitcherPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Whether the current platform / device supports alternate app icons.
  Future<bool> supportsAlternateIcons() {
    throw UnimplementedError(
      'supportsAlternateIcons() has not been implemented.',
    );
  }

  /// Sets the launcher / home-screen icon to [iconName].
  ///
  /// Pass `'default'` (or an empty string) to restore the primary icon.
  /// Throws a [PlatformException] with code `ICON_NOT_FOUND` when the name is
  /// not declared natively, or `SET_ICON_FAILED` on other failures.
  Future<void> setIcon(String iconName) {
    throw UnimplementedError('setIcon() has not been implemented.');
  }

  /// Returns the currently active alternate icon name, or `'default'` when the
  /// primary icon is active.
  Future<String> currentIcon() {
    throw UnimplementedError('currentIcon() has not been implemented.');
  }

  /// Returns the list of alternate icon names declared in the native
  /// manifest / Info.plist (does not include `'default'`).
  Future<List<String>> getAvailableIcons() {
    throw UnimplementedError('getAvailableIcons() has not been implemented.');
  }
}
