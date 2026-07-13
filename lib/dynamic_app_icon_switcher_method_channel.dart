import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dynamic_app_icon_switcher_platform_interface.dart';

/// Method-channel implementation of [DynamicAppIconSwitcherPlatform].
class MethodChannelDynamicAppIconSwitcher
    extends DynamicAppIconSwitcherPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('dynamic_app_icon_switcher');

  @override
  Future<bool> supportsAlternateIcons() async {
    final supported = await methodChannel.invokeMethod<bool>(
      'supportsAlternateIcons',
    );
    return supported ?? false;
  }

  @override
  Future<void> setIcon(String iconName) async {
    await methodChannel.invokeMethod<void>('setIcon', <String, dynamic>{
      'iconName': iconName,
    });
  }

  @override
  Future<String> currentIcon() async {
    final name = await methodChannel.invokeMethod<String>('currentIcon');
    return name ?? 'default';
  }

  @override
  Future<List<String>> getAvailableIcons() async {
    final icons = await methodChannel.invokeMethod<List<dynamic>>(
      'getAvailableIcons',
    );
    if (icons == null) {
      return const <String>[];
    }
    return icons.map((dynamic e) => e.toString()).toList(growable: false);
  }
}
