import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand_config_api.dart';
import 'dynamic_app_icon_service.dart';
import 'splash_cache_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dynamic App Icon Switcher',
      home: const SplashGate(),
    );
  }
}

/// Shows cached splash immediately, then syncs API in the background.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  final BrandConfigApi _brandApi = BrandConfigApi();
  final SplashCacheService _splashCache = SplashCacheService();
  final DynamicAppIconService _iconService = DynamicAppIconService();

  CachedSplash? _splash;
  bool _ready = false;
  String? _bootStatus;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = await _splashCache.loadCached();
    if (!mounted) return;
    setState(() {
      _splash = cached;
      _bootStatus = 'Showing cached splash…';
    });

    // Minimum splash visibility for demo.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    try {
      final brand = await _brandApi.fetchBrandConfig();

      if (mounted) {
        final synced = await _splashCache.syncFromApi(
          brand.splash,
          context: context,
        );
        if (mounted) setState(() => _splash = synced);
      }

      final apply = await _iconService.applyFromConfig(brand.appIcon);
      if (!mounted) return;
      setState(() {
        _bootStatus = apply.reason;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bootStatus = 'API failed — using last known local state.\n$e';
        _ready = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return _SplashView(
        splash: _splash,
        status: _bootStatus,
      );
    }
    return IconHomePage(
      iconService: _iconService,
      splashCache: _splashCache,
      initialStatus: _bootStatus,
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView({this.splash, this.status});

  final CachedSplash? splash;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final hasImage = splash?.hasImage == true;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            Image.network(
              splash!.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _DefaultSplashUi(),
            )
          else
            const _DefaultSplashUi(),
          if (status != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  status!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DefaultSplashUi extends StatelessWidget {
  const _DefaultSplashUi();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0D47A1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apps, size: 88, color: Colors.white.withOpacity(0.95)),
            const SizedBox(height: 16),
            const Text(
              'Default splash',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Fallback when no CDN splash is cached',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class IconHomePage extends StatefulWidget {
  const IconHomePage({
    super.key,
    required this.iconService,
    required this.splashCache,
    this.initialStatus,
  });

  final DynamicAppIconService iconService;
  final SplashCacheService splashCache;
  final String? initialStatus;

  @override
  State<IconHomePage> createState() => _IconHomePageState();
}

class _IconHomePageState extends State<IconHomePage> {
  final BrandConfigApi _brandApi = BrandConfigApi();
  bool _loadingConfig = true;
  bool _supported = false;
  String _current = 'default';
  List<String> _shipped = const <String>[];
  List<String> _picker = const <String>[];
  String? _activeFromApi;
  String? _iconVersion;
  String? _splashSummary;
  String? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadingConfig = true;
      _status = 'Loading brand config from API…';
    });
    try {
      final brand = await _brandApi.fetchBrandConfig();
      final apply = await widget.iconService.applyFromConfig(brand.appIcon);

      final supported = await widget.iconService.supportsAlternateIcons();
      final current = await widget.iconService.currentIcon();
      final shipped = await widget.iconService.getAvailableIcons();
      final picker = await widget.iconService.resolvePickerIcons(
        config: brand.appIcon,
      );

      final splashCached = await widget.splashCache.syncFromApi(
        brand.splash,
        context: context,
      );

      if (!mounted) return;
      setState(() {
        _supported = supported;
        _current = current;
        _shipped = shipped;
        _picker = picker;
        _activeFromApi = brand.appIcon.activeIcon;
        _iconVersion = brand.appIcon.iconVersion;
        _splashSummary = splashCached.hasImage
            ? 'CDN splash v${splashCached.imageVersion}'
            : 'Default splash';
        _loadingConfig = false;
        _status =
            '${apply.reason}\n'
            'Control layer = your HTTP API (not Firebase).';
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
      await widget.iconService.setIcon(name);
      final current = await widget.iconService.currentIcon();
      if (!mounted) return;
      setState(() {
        _current = current;
        _status =
            'Icon set to $current.\n'
            'Press Home — some launchers refresh after a few seconds.';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _status = '${e.code}: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Admin changes API `active_icon` → client refetches → applies without rebuild.
  Future<void> _adminSetActiveIcon(String name) async {
    if (_busy || _loadingConfig) return;
    setState(() {
      _busy = true;
      _status = 'Admin set active_icon=$name — fetching API…';
    });
    try {
      _brandApi.setActiveIconAsAdmin(name);
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = <String>['default', ..._picker];
    final adminChoices = <String>['default', ..._shipped];

    return Scaffold(
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
          Text(
            'API active_icon: ${_activeFromApi ?? '—'} '
            '(v${_iconVersion ?? '—'})',
          ),
          Text('Shipped (native): ${_shipped.join(', ')}'),
          Text('Splash: ${_splashSummary ?? '—'}'),
          Text('Picker (API ∩ schedule ∩ native): ${_picker.join(', ')}'),
          const SizedBox(height: 8),
          const Text(
            'Two steps:\n'
            '1. Add icons to the app once, then build/release.\n'
            '2. Admin changes active_icon via API anytime — no new store build.\n'
            '\n'
            'Client flow:\n'
            '• GET /branding → app_icon + splash\n'
            '• Apply active_icon when icon_version changes\n'
            '• Precache splash URL, then save locally',
          ),
          const SizedBox(height: 12),
          if (_status != null) Text(_status!),
          const SizedBox(height: 16),
          const Text(
            'Admin (API) — change active icon anytime',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Simulates your admin panel updating GET /branding. '
            'Only pre-shipped keys work.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in adminChoices)
                FilledButton.tonal(
                  onPressed: (_busy || _loadingConfig)
                      ? null
                      : () => _adminSetActiveIcon(name),
                  child: Text('API → $name'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Manual picker (local setIcon)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
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
            'Production: point BrandConfigApi at your real Dio baseUrl. '
            'Admin writes active_icon + icon_version; app only GETs /branding.',
          ),
        ],
      ),
    );
  }
}
