# dynamic_app_icon_switcher

Flutter plugin لتغيير **أيقونة التطبيق على الشاشة الرئيسية** أثناء التشغيل على Android و iOS.

---

## شرح سريع بالعربية — كيف تستخدمه؟

### الفكرة
الأيقونة على الشاشة الرئيسية **ليست صورة Flutter**.  
هي ملف أصلي داخل التطبيق:

| المنصة | أين تضع الصورة؟ | كيف تعلنها؟ |
|---|---|---|
| Android | `mipmap` أو `drawable` | `activity-alias` باسم `.icons.Name` |
| iOS | PNG خارج Asset Catalog | `CFBundleAlternateIcons` في `Info.plist` |

بعدها من Dart:

```dart
await DynamicAppIconSwitcher().setIcon('WorldCup'); // تغيير
await DynamicAppIconSwitcher().setIcon('default');  // رجوع للأصلية
```

### خطوات الاستخدام (من الصفر)

**1) ثبّت الحزمة**

```yaml
dependencies:
  dynamic_app_icon_switcher: ^0.1.0
```

**2) أضف الأيقونات الأصلية (مرة واحدة مع كل تصميم جديد = يحتاج build جديد)**

أسهل طريقة — شغّل سكربت التوليد:

```bash
# من جذر الحزمة — بصورة جاهزة
tool\add_alternate_icon.bat --name WorldCup --source C:\path\to\icon.png --example

# أو لون تجريبي بدون صورة
tool\add_alternate_icon.bat --name Promo --color E53935 --example
```

السكربت يقوم بـ:
1. توليد كل مقاسات Android (`mipmap-*`) و iOS (`@2x` / `@3x`)
2. إضافة `activity-alias` في `AndroidManifest.xml`
3. إضافة الإدخال في `Info.plist`
4. تسجيل الملفات في Xcode `project.pbxproj`

ثم: `flutter run` واستدعِ `setIcon('WorldCup')`.

تفاصيل أكثر: [`tool/README.md`](tool/README.md)

**3) في التطبيق: حمّل الإعداد من API ثم ابنِ الـ picker**

```dart
final plugin = DynamicAppIconSwitcher();

// من سيرفرك / Firebase Remote Config
final remote = await fetchIconConfigFromApi();

final picker = await plugin.resolvePickerIcons(remoteConfig: remote);
// مثال نتيجة: ['WorldCup', 'Green']

// لا تكتب أسماء الأيقونات ثابتة في الواجهة — استخدم picker
for (final name in picker) {
  // زر → plugin.setIcon(name)
}
```

شكل JSON المتوقع من الـ API:

```json
{
  "available_icons": ["Red", "Blue", "Green", "WorldCup"],
  "icon_schedule": [
    { "icon": "WorldCup", "from": "2026-06-01", "to": "2026-07-31" },
    { "icon": "Green", "from": "2026-07-01", "to": "2026-07-20" },
    { "icon": "Red", "from": "2026-01-01", "to": "2026-06-30" },
    { "icon": "Blue", "from": "2026-08-01", "to": "2026-12-31" }
  ]
}
```

المعنى:

- `available_icons` = الأيقونات المسموح عرضها من السيرفر
- `icon_schedule` = متى تظهر كل أيقونة (حسب التاريخ)
- البلجن يطبّق: **API ∩ الجدول الزمني ∩ الأيقونات المدمجة أصلاً**

**4) إذا الأيقونة الحالية اختفت من الـ picker**

```dart
final safe = plugin.fallbackIfUnavailable(
  current: await plugin.currentIcon(),
  visibleIcons: picker,
);
if (safe == 'default') {
  await plugin.setIcon('default');
}
```

### مهم جداً
- لا يمكن إضافة تصميم أيقونة جديد عبر Flutter `assets` أو رابط صورة أو Shorebird.
- أي تصميم جديد يحتاج إضافته في `mipmap` / iOS ثم رفع إصدار جديد للمتجر.
- بعد الإصدار، يمكنك إظهار/إخفاء الأيقونات عبر الـ API بدون build جديد.
- على بعض أجهزة Android (EMUI / MIUI) تحديث أيقونة الـ launcher قد يتأخر ثوانٍ بعد الضغط على Home.

انظر المثال: `example/lib/main.dart` و `example/lib/icon_config_api.dart`

---

## Install

```yaml
dependencies:
  dynamic_app_icon_switcher: ^0.1.0
```

```dart
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher.dart';
```

## API

| Method | Description |
|---|---|
| `supportsAlternateIcons()` | هل الجهاز يدعم تبديل الأيقونة؟ |
| `setIcon(name)` | يغيّر الأيقونة (`'default'` للأصلية) |
| `currentIcon()` | الاسم الحالي أو `'default'` |
| `getAvailableIcons()` | الأسماء المعلنة أصلياً في التطبيق |
| `resolvePickerIcons(remoteConfig: …)` | قائمة الـ picker بعد فلترة API + الجدول |
| `fallbackIfUnavailable(…)` | يرجع `'default'` إذا الأيقونة الحالية لم تعد متاحة |

## Usage (Dart)

```dart
final icons = DynamicAppIconSwitcher();

if (!await icons.supportsAlternateIcons()) return;

// Load from your API / Remote Config
final remoteConfig = await yourApi.fetchIconConfig();

final picker = await icons.resolvePickerIcons(remoteConfig: remoteConfig);

final current = await icons.currentIcon();
final safe = icons.fallbackIfUnavailable(
  current: current,
  visibleIcons: picker,
);
if (safe != current) {
  await icons.setIcon('default');
}

await icons.setIcon(picker.first); // e.g. WorldCup
print(await icons.currentIcon());
await icons.setIcon('default');
```

### API / Remote Config JSON

```json
{
  "available_icons": ["Red", "Blue", "Green", "WorldCup"],
  "icon_schedule": [
    { "icon": "WorldCup", "from": "2026-06-01", "to": "2026-07-31" },
    { "icon": "Green", "from": "2026-07-01", "to": "2026-07-20" },
    { "icon": "Red", "from": "2026-01-01", "to": "2026-06-30" },
    { "icon": "Blue", "from": "2026-08-01", "to": "2026-12-31" }
  ]
}
```

Picker logic:

`available_icons` ∩ active `icon_schedule` ∩ native aliases/plist

Icons listed by the API but **not** shipped natively are ignored / fail with `ICON_NOT_FOUND` on `setIcon`.

## Android setup

1. Put icon files in mipmap, e.g. `res/mipmap-*/ic_worldcup.png`
2. Keep the default `MainActivity` LAUNCHER intent-filter
3. Add one `activity-alias` per alternate icon — name must contain `.icons.<Name>`:

```xml
<activity-alias
    android:name=".icons.WorldCup"
    android:enabled="false"
    android:exported="true"
    android:icon="@mipmap/ic_worldcup"
    android:label="World Cup"
    android:targetActivity=".MainActivity">
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity-alias>
```

Dart name = part after `.icons.` → `setIcon('WorldCup')`

## iOS setup

1. Add PNGs **outside** the Asset Catalog (not in `AppIcon.appiconset`):
   - `WorldCup@2x.png` (120×120)
   - `WorldCup@3x.png` (180×180)
2. Add them to the Runner target **Copy Bundle Resources**
3. Declare in `Info.plist`:

```xml
<key>CFBundleIcons</key>
<dict>
  <key>CFBundleAlternateIcons</key>
  <dict>
    <key>WorldCup</key>
    <dict>
      <key>CFBundleIconFiles</key>
      <array>
        <string>WorldCup</string>
      </array>
      <key>UIPrerenderedIcon</key>
      <false/>
    </dict>
  </dict>
</dict>
```

Test on a **real iPhone** — Simulator is unreliable for home-screen icon changes.

## Adding a new icon (script)

Any developer can add an icon with one command:

```bash
# Windows
tool\add_alternate_icon.bat --name WorldCup --source path\to\icon.png --example

# macOS / Linux
chmod +x tool/add_alternate_icon.sh
./tool/add_alternate_icon.sh --name WorldCup --source ./icon.png --example

# Or placeholder color
tool\add_alternate_icon.bat --name Promo --color 8E24AA --example
```

For another Flutter app (not this example), pass explicit paths:

```bash
dart run tool/add_alternate_icon/bin/add_alternate_icon.dart \
  --name WorldCup \
  --source ./worldcup.png \
  --android-res path/to/android/app/src/main/res \
  --manifest path/to/android/app/src/main/AndroidManifest.xml \
  --ios-runner path/to/ios/Runner \
  --plist path/to/ios/Runner/Info.plist \
  --pbxproj path/to/ios/Runner.xcodeproj/project.pbxproj
```

See [`tool/README.md`](tool/README.md).

### Manual checklist (if you prefer)

1. Create artwork
2. Android: mipmap files + `.icons.Name` alias
3. iOS: `Name@2x.png` / `Name@3x.png` + plist key
4. Ship a new store build
5. Enable it later via API `available_icons` / `icon_schedule` (no new binary needed to show/hide)

## Error codes

| Code | Meaning |
|---|---|
| `PLATFORM_NOT_SUPPORTED` | الجهاز لا يدعم تبديل الأيقونة |
| `ICON_NOT_FOUND` | الاسم غير موجود في Manifest / Info.plist |
| `SET_ICON_FAILED` | فشل التغيير على المستوى الأصلي |

```dart
try {
  await icons.setIcon('Missing');
} on PlatformException catch (e) {
  // e.code → ICON_NOT_FOUND / SET_ICON_FAILED / …
}
```

## Known limitations

- بعض لانشرات Android (EMUI / MIUI / ColorOS) تؤخر تحديث الأيقونة بعد الخروج للـ Home
- iOS يظهر تنبيه نظام عند تغيير الأيقونة
- تصميم أيقونة جديد دائماً يحتاج إصدار تطبيق جديد
- صور Flutter `assets` أو الشبكة تصلح للمعاينة داخل التطبيق فقط، وليس لأيقونة الـ launcher

## Example app

```bash
cd example
flutter run
```

Demonstrates:

- Native icons: Red, Blue, Green, WorldCup
- Loading config from a simulated API (`icon_config_api.dart`)
- Schedule filtering
- Switching icons + restoring `default`

## License

MIT License © 2026 Ahmed Alam — see [LICENSE](LICENSE).
