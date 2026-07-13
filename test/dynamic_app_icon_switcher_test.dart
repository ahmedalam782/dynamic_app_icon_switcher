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
}
