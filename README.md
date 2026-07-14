# dynamic_app_icon_switcher

Flutter plugin to change the **home-screen launcher icon** at runtime on Android and iOS — controlled by **your Dio / HTTP API** (not Firebase / Firestore / Remote Config).

---

## الفكرة — Idea

**English:** Alternate launcher icons must be bundled in the app at build time. Your backend API only selects which pre-shipped icon key is active and serves a splash image URL. No store release is needed to *switch* between icons you already shipped — only to add *new* artwork.

**العربية:** أيقونة الـ Launcher لا يمكن تحميلها من الإنترنت وقت التشغيل. الأيقونات لازم تكون موجودة داخل التطبيق وقت الـ Build. الـ API يحدد فقط أي Key مفعّل (`active_icon`) ويرسل رابط الـ Splash. التبديل بين أيقونات موجودة مسبقًا لا يحتاج Release جديد — إضافة تصميم جديد فقط تحتاج Release.

| Piece | API sends | App does |
|---|---|---|
| **App icon** | `active_icon` + `icon_version` | Native `setIcon` for a **pre-bundled** key |
| **Splash** | CDN `image_url` + `image_version` | Precache → save locally → show on next launch |
| **Picker (optional)** | `available_icons` + `icon_schedule` | Filter against natively shipped icons |

---

## Architecture

```
Admin / Backend
      │
      │  GET /branding   (via Dio)
      ▼
┌─────────────────────────────────────┐
│  { app_icon: {...}, splash: {...} }│
└─────────────────────────────────────┘
      │
      ▼
   User App
      │
      ├─► BrandConfigApi (Dio)
      │     • GET /branding
      │
      ├─► DynamicAppIconService
      │     • read active_icon + icon_version
      │     • skip if same key/version already applied
      │     • skip if key not shipped natively
      │     • native setIcon (Android alias / iOS alternate)
      │
      └─► SplashCacheService
            • paint last cached splash immediately
            • fetch API in background
            • precache CDN image → persist on success
            • next cold start shows new splash reliably
```

**Control layer = your API over Dio.** Same product flow as a Firestore setup — only the transport is Dio.

---

## Install

```yaml
dependencies:
  dynamic_app_icon_switcher: ^0.1.0
  dio: ^5.9.0                  # fetch branding from your API
  shared_preferences: ^2.5.3   # persist last applied icon + splash (example)
```

```dart
import 'package:dio/dio.dart';
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher.dart';
```

---

## Backend API contract

Single endpoint (name is up to you), e.g. `GET /branding`:

```json
{
  "app_icon": {
    "enabled": true,
    "active_icon": "Ramadan",
    "icon_version": "3",
    "available_icons": ["Ramadan", "EidAdha", "Red", "Blue", "Green", "WorldCup"],
    "icon_schedule": [
      { "icon": "Ramadan", "from": "2026-02-01", "to": "2026-03-31" },
      { "icon": "EidAdha", "from": "2026-05-01", "to": "2026-06-30" },
      { "icon": "WorldCup", "from": "2026-06-01", "to": "2026-07-31" }
    ]
  },
  "splash": {
    "use_default_splash": false,
    "image_url": "https://cdn.example.com/ramadan-splash.webp",
    "image_version": "4"
  }
}
```

### `app_icon` fields

| Field | Type | Purpose |
|---|---|---|
| `enabled` | `bool` | When `false`, do not change the launcher icon |
| `active_icon` | `string` | Pre-bundled key to apply (e.g. `Ramadan`, `EidAdha`). Use `default` for primary |
| `icon_version` | `string` | Bump when `active_icon` changes so clients re-apply |
| `available_icons` | `string[]` | Optional allow-list for a manual picker UI |
| `icon_schedule` | `object[]` | Optional date windows (`from` / `to` as `YYYY-MM-DD`) |

### `splash` fields

| Field | Type | Purpose |
|---|---|---|
| `use_default_splash` | `bool` | When `true`, use built-in / last-default splash UI |
| `image_url` | `string` | CDN URL (ImageKit, S3, etc.) |
| `image_version` | `string` | Bump when the image changes (cache bust via `?splash_version=`) |

To restore default splash:

```json
{
  "splash": {
    "use_default_splash": true,
    "image_url": "",
    "image_version": "5"
  }
}
```

---

## Usage

### 1) Fetch with Dio and parse

```dart
import 'package:dio/dio.dart';
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
final res = await dio.get<Map<String, dynamic>>('/branding');
final brand = RemoteBrandConfig.parse(res.data!);
```

Or use the example client (`BrandConfigApi` wraps Dio):

```dart
final brand = await BrandConfigApi(
  dio: Dio(BaseOptions(baseUrl: 'https://api.example.com')),
).fetchBrandConfig();
```

The example app ships a **demo Dio interceptor** so `flutter run` works without a live server. Swap in your real `Dio` instance for production.

### 2) Apply launcher icon (only when needed)

```dart
final plugin = DynamicAppIconSwitcher();
final prefs = await SharedPreferences.getInstance();

final applied = await plugin.applyActiveIconIfNeeded(
  config: brand.appIcon,
  lastAppliedIcon: prefs.getString('applied_active_icon'),
  lastAppliedVersion: prefs.getString('applied_icon_version'),
);

if (applied != null) {
  await prefs.setString('applied_active_icon', applied);
  await prefs.setString('applied_icon_version', brand.appIcon.iconVersion);
}
```

Or use the example wrapper `DynamicAppIconService`, which handles persistence for you.

### 3) Build a picker (never hardcode icon names in UI)

```dart
final picker = await plugin.resolvePickerIcons(
  remoteConfig: res.data,
);
// picker = available_icons ∩ active schedule ∩ natively shipped icons

for (final name in picker) {
  // show button → plugin.setIcon(name)
}
```

### 4) Fallback when current icon leaves the picker

```dart
final current = await plugin.currentIcon();
final safe = plugin.fallbackIfUnavailable(
  current: current,
  visibleIcons: picker,
);
if (safe != current) {
  await plugin.setIcon('default');
}
```

### 5) Splash startup flow

Do **not** block the first frame on the network:

1. Read last splash from `shared_preferences` → paint immediately
2. Fetch API with Dio in the background
3. Precache the CDN image
4. Persist config only after precache succeeds
5. Next cold start shows the new splash

See `example/lib/splash_cache_service.dart` and `example/lib/main.dart` (`SplashGate`).

---

## Plugin API

| Method | Description |
|---|---|
| `supportsAlternateIcons()` | Whether the device supports alternate icons |
| `setIcon(name)` | Switch icon (`'default'` restores primary) |
| `currentIcon()` | Active name or `'default'` |
| `getAvailableIcons()` | Names declared in the native binary |
| `resolvePickerIcons(remoteConfig: …)` | Picker = API ∩ schedule ∩ native |
| `applyActiveIconIfNeeded(…)` | Apply `active_icon` when key/version changed |
| `fallbackIfUnavailable(…)` | Returns `'default'` if current icon left the picker |

### Models (exported)

| Class | Role |
|---|---|
| `RemoteBrandConfig` | Parses full `{ app_icon, splash }` JSON |
| `RemoteAppIconConfig` | `enabled`, `active_icon`, `icon_version`, allow-list, schedule |
| `RemoteSplashConfig` | `use_default_splash`, `image_url`, `image_version`, cache-busted URL |
| `IconAvailability` / `IconScheduleEntry` | Schedule filtering helpers |

---

## How admin changes the icon anytime

Two separate steps:

| Step | Who | What | Needs store release? |
|---|---|---|---|
| **1. Ship artwork** | Developer | Add icon PNGs + Android `activity-alias` + iOS `CFBundleAlternateIcons`, then build | **Yes** (once per new design) |
| **2. Activate icon** | Admin / backend | Set `active_icon` + bump `icon_version` on `GET /branding` | **No** |

```
Admin panel ──writes──► your API (active_icon = "EidAdha", icon_version = "4")
                              │
                     GET /branding (Dio)
                              ▼
                         User app
                              │
              applyActiveIconIfNeeded / applyFromConfig
                              ▼
                 Native setIcon('EidAdha')  ← key already in the binary
```

**Admin checklist**

1. Choose a key that already exists in the app (e.g. `Ramadan`, `EidAdha`).
2. Update branding JSON: `"active_icon": "EidAdha"`, `"icon_version": "<new>"`.
3. Clients fetch `/branding` (on launch, pull-to-refresh, or push) and switch.
4. To add a *new* picture never shipped before → run `tool/add_alternate_icon` and ship a new build first.

The example app includes an **Admin (API)** section that mutates the demo branding store and re-fetches — same path as production, no rebuild required for step 2.

---

## Important rules

- **New launcher artwork** → new store build (`mipmap` / `CFBundleAlternateIcons`).
- **Existing keys** → switch anytime via API (`active_icon` + bump `icon_version`).
- **Splash CDN images** → change anytime without a release.
- **Unsupported icon key** → skip silently; never crash or block app open.
- **Same icon + version already applied** → skip native switch (no redundant OS call).
- **API / Dio failure** → continue with last successful local state.

---

## Ship alternate icons (one-time per design)

Use the bundled script to generate Android mipmaps, iOS PNGs, manifest, and plist entries:

```bash
# Windows — example app
tool\add_alternate_icon.bat --name Ramadan --source C:\path\to\icon.png --example

# macOS / Linux
./tool/add_alternate_icon.sh --name EidAdha --source ./icon.png --example

# Placeholder color (no source image)
tool\add_alternate_icon.bat --name Promo --color E53935 --example
```

For another Flutter app, pass explicit paths — see [`tool/README.md`](tool/README.md).

Then:

```dart
await DynamicAppIconSwitcher().setIcon('Ramadan');
await DynamicAppIconSwitcher().setIcon('EidAdha');
await DynamicAppIconSwitcher().setIcon('default');
```

---

## Android setup

1. Put icon files in mipmap, e.g. `res/mipmap-*/ic_ramadan.png`
2. Keep the default `MainActivity` LAUNCHER intent-filter
3. Add one `activity-alias` per alternate icon — name **must** contain `.icons.<Name>`:

```xml
<activity-alias
    android:name=".icons.Ramadan"
    android:enabled="false"
    android:exported="true"
    android:icon="@mipmap/ic_ramadan"
    android:label="Ramadan"
    android:targetActivity=".MainActivity">
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity-alias>
```

Dart name = part after `.icons.` → `setIcon('Ramadan')`

> **Windows tip:** if the project is on `D:` and Pub cache is on `C:`, add `kotlin.incremental=false` to `android/gradle.properties` to avoid Kotlin cache errors across drive roots.

---

## iOS setup

1. Add PNGs **outside** the Asset Catalog (not in `AppIcon.appiconset`):
   - `Ramadan@2x.png` (120×120)
   - `Ramadan@3x.png` (180×180)
2. Add them to the Runner target **Copy Bundle Resources**
3. Declare in `Info.plist`:

```xml
<key>CFBundleIcons</key>
<dict>
  <key>CFBundleAlternateIcons</key>
  <dict>
    <key>Ramadan</key>
    <dict>
      <key>CFBundleIconFiles</key>
      <array>
        <string>Ramadan</string>
      </array>
      <key>UIPrerenderedIcon</key>
      <false/>
    </dict>
  </dict>
</dict>
```

Test on a **real iPhone** — Simulator is unreliable for home-screen icon changes.

---

## Example app

```bash
cd example
flutter pub get
flutter run
```

| File | Role |
|---|---|
| `example/lib/brand_config_api.dart` | Dio client (`GET /branding`) + demo interceptor |
| `example/lib/dynamic_app_icon_service.dart` | Apply `active_icon` + persist version |
| `example/lib/splash_cache_service.dart` | Cached splash + CDN precache |
| `example/lib/main.dart` | `SplashGate` boot flow + icon picker demo |

Demonstrates:

- Dio-driven `active_icon` + `icon_version` (demo: `Ramadan`)
- **Admin (API)** buttons: change `active_icon` anytime → refetch → apply (no rebuild)
- Seasonal icons: `Ramadan`, `EidAdha`, plus Red / Blue / Green / WorldCup / Promo
- Cached splash (instant first paint, background sync)
- Picker filtered by `available_icons` ∩ schedule ∩ native
- Graceful fallback when Dio / API fails

---

## Error codes

| Code | Meaning |
|---|---|
| `PLATFORM_NOT_SUPPORTED` | Device does not support alternate icons |
| `ICON_NOT_FOUND` | Name missing from AndroidManifest / Info.plist |
| `SET_ICON_FAILED` | Native switch failed |

```dart
try {
  await plugin.setIcon('Missing');
} on PlatformException catch (e) {
  // e.code → ICON_NOT_FOUND / SET_ICON_FAILED / …
}
```

---

## Known limitations

- Some Android launchers (EMUI / MIUI / ColorOS) refresh the icon a few seconds after pressing Home
- iOS may show a system alert when the icon changes
- New icon **designs** always require a new app store release
- Flutter `assets` and network images are for in-app splash / previews only — not the OS launcher icon

---

## License

MIT License © 2026 Ahmed Alam — see [LICENSE](LICENSE).
