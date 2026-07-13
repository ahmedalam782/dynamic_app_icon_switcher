import 'package:flutter_test/flutter_test.dart';
import 'package:dynamic_app_icon_switcher_example/main.dart';
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDynamicAppIconSwitcherPlatform
    with MockPlatformInterfaceMixin
    implements DynamicAppIconSwitcherPlatform {
  @override
  Future<bool> supportsAlternateIcons() => Future<bool>.value(true);

  @override
  Future<void> setIcon(String iconName) async {}

  @override
  Future<String> currentIcon() => Future<String>.value('default');

  @override
  Future<List<String>> getAvailableIcons() =>
      Future<List<String>>.value(const <String>['Red', 'Blue', 'Green']);
}

void main() {
  testWidgets('Example app loads', (WidgetTester tester) async {
    DynamicAppIconSwitcherPlatform.instance =
        MockDynamicAppIconSwitcherPlatform();
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Supported:'), findsOneWidget);
  });
}
