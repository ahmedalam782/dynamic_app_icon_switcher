import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher.dart';

import 'icon_config_api.dart';

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

  bool _loadingConfig = true;
  bool _supported = false;
  String _current = 'default';
  List<String> _shipped = const <String>[];
  List<String> _picker = const <String>[];
  Map<String, dynamic>? _remoteConfig;
  String? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// 1) Load config from API
  /// 2) Intersect with natively shipped icons + schedule
  /// 3) Build picker (never hardcode icon names in the UI)
  Future<void> _refresh() async {
    setState(() {
      _loadingConfig = true;
      _status = 'Loading icon config from API…';
    });
    try {
      // ← In a real app this is your backend / Firebase Remote Config.
      final remoteConfig = await IconConfigApi.fetchIconConfig();

      final supported = await _plugin.supportsAlternateIcons();
      final current = await _plugin.currentIcon();
      final shipped = await _plugin.getAvailableIcons();
      final picker = await _plugin.resolvePickerIcons(
        remoteConfig: remoteConfig,
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
        _remoteConfig = remoteConfig;
        _supported = supported;
        _current = safeCurrent == current ? current : 'default';
        _shipped = shipped;
        _picker = picker;
        _loadingConfig = false;
        _status =
            'Config loaded from API.\n'
            'Picker = available_icons ∩ icon_schedule(now) ∩ native.';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingConfig = false;
        _status = '${e.code}: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingConfig = false;
        _status = 'Failed to load API config: $e';
      });
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
            'Icon set to $current.\n'
            'Press Home and wait — some launchers (EMUI/MIUI/ColorOS) '
            'refresh the icon after a few seconds, not instantly.';
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
    final scheduleCount =
        (_remoteConfig?['icon_schedule'] as List<dynamic>?)?.length ?? 0;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Dynamic App Icon Switcher'),
          actions: [
            IconButton(
              tooltip: 'Reload API config',
              onPressed: _loadingConfig ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loadingConfig) const LinearProgressIndicator(),
            Text('Supported: $_supported'),
            Text('Current icon: $_current'),
            Text('Shipped (native): ${_shipped.join(', ')}'),
            Text('API schedule entries: $scheduleCount'),
            Text('Picker (API ∩ schedule ∩ native): ${_picker.join(', ')}'),
            const SizedBox(height: 8),
            const Text(
              'Flow:\n'
              '1. API returns available_icons + icon_schedule\n'
              '2. Plugin keeps only icons that exist natively\n'
              '3. Schedule hides expired / future icons\n'
              '4. UI builds buttons from picker only',
            ),
            const SizedBox(height: 12),
            if (_status != null) Text(_status!),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in choices)
                  FilledButton(
                    onPressed: (_busy || _loadingConfig)
                        ? null
                        : () => _setIcon(name),
                    child: Text(name),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Tip: after switching, press Home and check the launcher icon.\n'
              'Edit example/lib/icon_config_api.dart to point at your real API.',
            ),
          ],
        ),
      ),
    );
  }
}
