import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final DynamicAppIconSwitcher _plugin = DynamicAppIconSwitcher();

  bool _supported = false;
  String _current = 'default';
  List<String> _shipped = const <String>[];
  List<String> _picker = const <String>[];
  String? _status;
  bool _busy = false;

  /// Demo Remote Config payload — swap this JSON without shipping a new binary
  /// to change which icons appear in the picker.
  static const Map<String, dynamic> _demoRemoteConfig = <String, dynamic>{
    'available_icons': <String>['Red', 'Blue', 'Green'],
    'icon_schedule': <Map<String, String>>[
      // Leave empty / adjust dates to demo schedule filtering.
    ],
  };

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final supported = await _plugin.supportsAlternateIcons();
      final current = await _plugin.currentIcon();
      final shipped = await _plugin.getAvailableIcons();
      final picker = await _plugin.resolvePickerIcons(
        remoteConfig: _demoRemoteConfig,
      );
      final safeCurrent = _plugin.fallbackIfUnavailable(
        current: current,
        visibleIcons: picker,
      );
      if (safeCurrent != current) {
        await _plugin.setIcon('default');
      }
      if (!mounted) return;
      setState(() {
        _supported = supported;
        _current = safeCurrent == current ? current : 'default';
        _shipped = shipped;
        _picker = picker;
        _status = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _status = '${e.code}: ${e.message}');
    }
  }

  Future<void> _setIcon(String name) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Switching to $name…';
    });
    try {
      await _plugin.setIcon(name);
      final current = await _plugin.currentIcon();
      if (!mounted) return;
      setState(() {
        _current = current;
        _status =
            'Icon set to $current. Background the app to confirm the launcher icon.';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _status = '${e.code}: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = <String>['default', ..._picker];
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Dynamic App Icon Switcher')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Supported: $_supported'),
            Text('Current icon: $_current'),
            Text('Shipped (native): ${_shipped.join(', ')}'),
            Text('Picker (remote ∩ native): ${_picker.join(', ')}'),
            const SizedBox(height: 12),
            if (_status != null) Text(_status!),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in choices)
                  FilledButton(
                    onPressed: _busy ? null : () => _setIcon(name),
                    child: Text(name),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Tip: after switching, press Home and check the launcher icon. '
              'Some launchers (EMUI/MIUI) refresh with a delay.',
            ),
          ],
        ),
      ),
    );
  }
}
