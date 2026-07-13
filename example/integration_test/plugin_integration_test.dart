// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('supportsAlternateIcons returns a bool', (WidgetTester tester) async {
    final DynamicAppIconSwitcher plugin = DynamicAppIconSwitcher();
    final bool supported = await plugin.supportsAlternateIcons();
    expect(supported, isA<bool>());
  });
}
