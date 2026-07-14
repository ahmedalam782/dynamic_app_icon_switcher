import 'package:flutter_test/flutter_test.dart';

import 'package:dynamic_app_icon_switcher_example/demo_brand_store.dart';

void main() {
  late DemoBrandStore store;

  setUp(() {
    store = DemoBrandStore.instance;
    store.reset();
  });

  test('admin can change active_icon anytime and bumps icon_version', () {
    final initial = store.payload['app_icon'] as Map<String, dynamic>;
    expect(initial['active_icon'], 'Ramadan');
    expect(initial['icon_version'], '3');

    store.setActiveIcon('EidAdha');

    final updated = store.payload['app_icon'] as Map<String, dynamic>;
    expect(updated['active_icon'], 'EidAdha');
    expect(updated['icon_version'], '4');
    expect(updated['enabled'], isTrue);
  });

  test('admin can disable icon switching without changing shipped artwork', () {
    store.setActiveIcon('default', enabled: false);
    final appIcon = store.payload['app_icon'] as Map<String, dynamic>;
    expect(appIcon['active_icon'], 'default');
    expect(appIcon['enabled'], isFalse);
    expect(appIcon['icon_version'], '4');
  });
}
