# add_alternate_icon

Generates Android + iOS alternate launcher icons and wires native config.

## Quick start (from repo root)

**With your image:**

```bash
# Windows
tool\add_alternate_icon.bat --name WorldCup --source path\to\icon.png --example

# macOS / Linux
./tool/add_alternate_icon.sh --name WorldCup --source ./icon.png --example
```

**Placeholder color (no source image):**

```bash
tool\add_alternate_icon.bat --name Promo --color E53935 --example
```

**Your own Flutter app (not this example):**

```bash
dart run tool/add_alternate_icon/bin/add_alternate_icon.dart ^
  --name WorldCup ^
  --source C:\icons\worldcup.png ^
  --android-res path\to\android\app\src\main\res ^
  --manifest path\to\android\app\src\main\AndroidManifest.xml ^
  --ios-runner path\to\ios\Runner ^
  --plist path\to\ios\Runner\Info.plist ^
  --pbxproj path\to\ios\Runner.xcodeproj\project.pbxproj
```

## What it does

1. Creates Android mipmaps: `ic_<snake_name>.png` in mdpi…xxxhdpi
2. Creates iOS `Name@2x.png` (120) and `Name@3x.png` (180)
3. Inserts `activity-alias` `.icons.Name` into `AndroidManifest.xml`
4. Inserts `CFBundleAlternateIcons` entry into `Info.plist`
5. Registers PNGs in `project.pbxproj` (when provided)

Then in Dart: `setIcon('Name')`.

## Arabic — للمطوّر

```text
1) جهّز صورة مربعة (يفضّل 1024×1024)
2) شغّل السكربت بالاسم المطلوب
3) أعد بناء التطبيق بالكامل (flutter run)
4) استدعِ setIcon('الاسم')
5) أضف الاسم لاحقاً في API / Remote Config إذا أردت إظهاره في الـ picker
```
