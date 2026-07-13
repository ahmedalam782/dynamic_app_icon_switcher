import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelDynamicAppIconSwitcher platform =
      MethodChannelDynamicAppIconSwitcher();
  const MethodChannel channel = MethodChannel('dynamic_app_icon_switcher');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'supportsAlternateIcons':
              return true;
            case 'currentIcon':
              return 'default';
            case 'getAvailableIcons':
              return <String>['Red', 'Blue'];
            case 'setIcon':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('method channel API', () async {
    expect(await platform.supportsAlternateIcons(), isTrue);
    expect(await platform.currentIcon(), 'default');
    expect(await platform.getAvailableIcons(), <String>['Red', 'Blue']);
    await platform.setIcon('Red');
  });
}
