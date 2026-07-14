import 'package:dynamic_app_icon_switcher/src/icon_availability.dart';
import 'package:dynamic_app_icon_switcher/src/remote_brand_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher.dart';
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher_platform_interface.dart';
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDynamicAppIconSwitcherPlatform
    with MockPlatformInterfaceMixin
    implements DynamicAppIconSwitcherPlatform {
  String _current = 'default';

  @override
  Future<bool> supportsAlternateIcons() => Future<bool>.value(true);

  @override
  Future<void> setIcon(String iconName) async {
    _current = iconName;
  }

  @override
  Future<String> currentIcon() => Future<String>.value(_current);

  @override
  Future<List<String>> getAvailableIcons() =>
      Future<List<String>>.value(const <String>['Red', 'Blue', 'Green']);
}

void main() {
  final DynamicAppIconSwitcherPlatform initialPlatform =
      DynamicAppIconSwitcherPlatform.instance;

  test('$MethodChannelDynamicAppIconSwitcher is the default instance', () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelDynamicAppIconSwitcher>(),
    );
  });

  test('supportsAlternateIcons / setIcon / currentIcon', () async {
    final DynamicAppIconSwitcher plugin = DynamicAppIconSwitcher();
    final MockDynamicAppIconSwitcherPlatform fakePlatform =
        MockDynamicAppIconSwitcherPlatform();
    DynamicAppIconSwitcherPlatform.instance = fakePlatform;

    expect(await plugin.supportsAlternateIcons(), isTrue);
    await plugin.setIcon('Red');
    expect(await plugin.currentIcon(), 'Red');
    expect(await plugin.getAvailableIcons(), <String>['Red', 'Blue', 'Green']);
  });

  test('IconAvailability intersects remote with shipped', () {
    final List<String> visible = IconAvailability.resolveAvailable(
      shippedIcons: const <String>['Red', 'Blue', 'Green'],
      availableFromRemote: const <String>['Blue', 'Purple'],
    );
    expect(visible, <String>['Blue']);
  });

  test('fallbackIfUnavailable restores default', () {
    expect(
      IconAvailability.fallbackIfUnavailable(
        currentIcon: 'Green',
        visibleIcons: const <String>['Red', 'Blue'],
      ),
      'default',
    );
  });

  test('RemoteBrandConfig parses API app_icon + splash', () {
    final brand = RemoteBrandConfig.parse(<String, dynamic>{
      'app_icon': <String, dynamic>{
        'enabled': true,
        'active_icon': 'WorldCup',
        'icon_version': '2',
        'available_icons': <String>['Red', 'WorldCup'],
      },
      'splash': <String, dynamic>{
        'use_default_splash': false,
        'image_url': 'https://cdn.example.com/a.webp',
        'image_version': '4',
      },
    });

    expect(brand.appIcon.activeIcon, 'WorldCup');
    expect(brand.appIcon.iconVersion, '2');
    expect(brand.splash.hasRemoteImage, isTrue);
    expect(
      brand.splash.cacheBustedUrl,
      'https://cdn.example.com/a.webp?splash_version=4',
    );
    expect(
      brand.appIcon.shouldApply(
        shippedIcons: <String>{'WorldCup'},
        lastAppliedIcon: 'Red',
        lastAppliedVersion: '1',
      ),
      isTrue,
    );
    expect(
      brand.appIcon.shouldApply(
        shippedIcons: <String>{'WorldCup'},
        lastAppliedIcon: 'WorldCup',
        lastAppliedVersion: '2',
      ),
      isFalse,
    );
  });

  test('applyActiveIconIfNeeded skips same version', () async {
    final DynamicAppIconSwitcher plugin = DynamicAppIconSwitcher();
    final MockDynamicAppIconSwitcherPlatform fakePlatform =
        MockDynamicAppIconSwitcherPlatform();
    DynamicAppIconSwitcherPlatform.instance = fakePlatform;

    final skipped = await plugin.applyActiveIconIfNeeded(
      config: const RemoteAppIconConfig(
        activeIcon: 'Red',
        iconVersion: '2',
      ),
      lastAppliedIcon: 'Red',
      lastAppliedVersion: '2',
    );
    expect(skipped, isNull);
    expect(await plugin.currentIcon(), 'default');

    final applied = await plugin.applyActiveIconIfNeeded(
      config: const RemoteAppIconConfig(
        activeIcon: 'Red',
        iconVersion: '3',
      ),
      lastAppliedIcon: 'default',
      lastAppliedVersion: '1',
    );
    expect(applied, 'Red');
    expect(await plugin.currentIcon(), 'Red');
  });
}
