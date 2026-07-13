# dynamic_app_icon_switcher

Flutter plugin to switch the **launcher / home-screen icon** at runtime on
Android and iOS.

> **Verification status:** Core Dart + native implementations are in place.
> Full device verification (Phase 4) must pass before treating platform support
> as production-ready. See known limitations below for launcher quirks.

## Install

```yaml
dependencies:
  dynamic_app_icon_switcher: ^0.1.0
```

## Usage

```dart
final icons = DynamicAppIconSwitcher();

if (await icons.supportsAlternateIcons()) {
  await icons.setIcon('Red');          // alternate
  print(await icons.currentIcon());  // Red
  await icons.setIcon('default');      // restore primary
}

// Picker list = native shipped icons ∩ Remote Config
final picker = await icons.resolvePickerIcons(remoteConfig: {
  'available_icons': ['Red', 'Blue'],
});
```

## Android setup

Add `activity-alias` entries whose names contain `.icons.<Name>`:

```xml
<activity-alias
    android:name=".icons.Red"
    android:enabled="false"
    android:exported="true"
    android:icon="@drawable/ic_icon_red"
    android:targetActivity=".MainActivity">
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity-alias>
```

Keep the primary `MainActivity` LAUNCHER filter for the default icon.
Call `setIcon('default')` to restore it.

## iOS setup

1. Add alternate icon PNGs **outside** the Asset Catalog (e.g. `Red@2x.png`,
   `Red@3x.png`) and include them in Copy Bundle Resources.
2. Declare them in `Info.plist` under `CFBundleIcons` → `CFBundleAlternateIcons`.

```xml
<key>CFBundleAlternateIcons</key>
<dict>
  <key>Red</key>
  <dict>
    <key>CFBundleIconFiles</key>
    <array>
      <string>Red</string>
    </array>
  </dict>
</dict>
```

Test on a **real device** — the simulator does not reliably reflect home-screen
icon changes.

## Remote Config (no new icon designs without a build)

Icons are native resources. You **cannot** add a brand-new icon design via
Flutter assets, network images, or Shorebird. You **can** control which
already-shipped icons appear in a picker via Remote Config:

```json
{
  "available_icons": ["England", "Argentina", "Brazil"],
  "icon_schedule": [
    { "icon": "England", "from": "2026-06-01", "to": "2026-07-15" }
  ]
}
```

## Error codes

| Code | Meaning |
|---|---|
| `PLATFORM_NOT_SUPPORTED` | Device/OS cannot change icons |
| `ICON_NOT_FOUND` | Name not declared in manifest / plist |
| `SET_ICON_FAILED` | Native change failed |

## Known limitations

- Some Android launchers (EMUI / MIUI) refresh the icon with a delay after
  backgrounding the app.
- iOS shows a system confirmation alert when the icon changes.
- New icon artwork always requires a store/binary release.

## License

See [LICENSE](LICENSE).
