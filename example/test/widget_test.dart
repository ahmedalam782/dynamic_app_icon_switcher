import 'package:flutter_test/flutter_test.dart';
import 'package:dynamic_app_icon_switcher_example/main.dart';
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      Future<List<String>>.value(
        const <String>[
          'Red',
          'Blue',
          'Green',
          'WorldCup',
          'Ramadan',
          'EidAdha',
        ],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DynamicAppIconSwitcherPlatform.instance =
        MockDynamicAppIconSwitcherPlatform();
  });

  testWidgets('Example app loads home after splash', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(SplashGate), findsOneWidget);

    // Splash delay 900ms + API 400ms, then home _refresh API 400ms.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(); // flush post-frame work
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Supported:'), findsOneWidget);
    expect(find.textContaining('API active_icon:'), findsOneWidget);
  });
}
