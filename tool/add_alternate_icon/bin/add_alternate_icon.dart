import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Generates launcher icon assets and wires Android + iOS native config.
///
/// Examples:
/// ```bash
/// dart run bin/add_alternate_icon.dart --name WorldCup --source ./my_icon.png
/// dart run bin/add_alternate_icon.dart --name Promo --color F9A825 --example
/// dart run bin/add_alternate_icon.dart --name Flag --source flag.png \
///   --android-res path/to/android/app/src/main/res \
///   --manifest path/to/AndroidManifest.xml \
///   --ios-runner path/to/ios/Runner \
///   --plist path/to/Info.plist \
///   --pbxproj path/to/project.pbxproj
/// ```
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'name',
      abbr: 'n',
      help: 'Icon id used in Dart setIcon("Name") and .icons.Name',
      mandatory: true,
    )
    ..addOption(
      'source',
      abbr: 's',
      help: 'Source PNG/JPG (square recommended, >= 1024px).',
    )
    ..addOption(
      'color',
      abbr: 'c',
      help: 'Hex color placeholder if --source is omitted, e.g. F9A825 or #E53935',
      defaultsTo: 'F9A825',
    )
    ..addFlag(
      'example',
      help: 'Target this plugin\'s example/ app paths automatically.',
      defaultsTo: false,
    )
    ..addOption('android-res', help: 'Path to android/.../res')
    ..addOption('manifest', help: 'Path to AndroidManifest.xml')
    ..addOption('ios-runner', help: 'Path to ios/Runner')
    ..addOption('plist', help: 'Path to Info.plist')
    ..addOption('pbxproj', help: 'Path to project.pbxproj')
    ..addOption(
      'label',
      help: 'Android android:label for the alias',
    )
    ..addFlag(
      'skip-pbxproj',
      help: 'Do not patch Xcode project.pbxproj (manual add in Xcode).',
      defaultsTo: false,
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  late ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  if (args['help'] as bool) {
    stdout.writeln(parser.usage);
    return;
  }

  final name = (args['name'] as String).trim();
  if (!_isValidName(name)) {
    stderr.writeln(
      'Invalid --name "$name". Use letters/digits only, starting with a letter '
      '(e.g. WorldCup, Flag1).',
    );
    exitCode = 64;
    return;
  }

  final repoRoot = _findRepoRoot();
  final useExample = args['example'] as bool;

  final androidRes = _resolvePath(
    explicit: args['android-res'] as String?,
    exampleDefault: useExample || _allExplicitMissing(args)
        ? p.join(
            repoRoot,
            'example',
            'android',
            'app',
            'src',
            'main',
            'res',
          )
        : null,
  );
  final manifest = _resolvePath(
    explicit: args['manifest'] as String?,
    exampleDefault: useExample || _allExplicitMissing(args)
        ? p.join(
            repoRoot,
            'example',
            'android',
            'app',
            'src',
            'main',
            'AndroidManifest.xml',
          )
        : null,
  );
  final iosRunner = _resolvePath(
    explicit: args['ios-runner'] as String?,
    exampleDefault: useExample || _allExplicitMissing(args)
        ? p.join(repoRoot, 'example', 'ios', 'Runner')
        : null,
  );
  final plist = _resolvePath(
    explicit: args['plist'] as String?,
    exampleDefault: useExample || _allExplicitMissing(args)
        ? p.join(repoRoot, 'example', 'ios', 'Runner', 'Info.plist')
        : null,
  );
  final pbxproj = _resolvePath(
    explicit: args['pbxproj'] as String?,
    exampleDefault: useExample || _allExplicitMissing(args)
        ? p.join(
            repoRoot,
            'example',
            'ios',
            'Runner.xcodeproj',
            'project.pbxproj',
          )
        : null,
  );

  if (androidRes == null ||
      manifest == null ||
      iosRunner == null ||
      plist == null) {
    stderr.writeln(
      'Missing paths. Pass --example, or provide --android-res --manifest '
      '--ios-runner --plist [--pbxproj].',
    );
    exitCode = 64;
    return;
  }

  final sourcePath = args['source'] as String?;
  final label = (args['label'] as String?)?.trim().isNotEmpty == true
      ? (args['label'] as String).trim()
      : name;
  final mipmapName = 'ic_${_toSnake(name)}';

  stdout.writeln('Generating icon "$name"...');
  final master = await _loadOrCreateMaster(
    sourcePath: sourcePath,
    colorHex: args['color'] as String,
  );

  // --- Android mipmaps ---
  const androidSizes = <String, int>{
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  for (final entry in androidSizes.entries) {
    final dir = Directory(p.join(androidRes, entry.key));
    dir.createSync(recursive: true);
    final out = File(p.join(dir.path, '$mipmapName.png'));
    _writePng(out, master, entry.value);
    stdout.writeln('  Android: ${out.path}');
  }

  // --- iOS alternate icons ---
  final iosSizes = <String, int>{
    '$name@2x.png': 120,
    '$name@3x.png': 180,
  };
  for (final entry in iosSizes.entries) {
    final out = File(p.join(iosRunner, entry.key));
    _writePng(out, master, entry.value);
    stdout.writeln('  iOS:     ${out.path}');
  }
  final altDir = Directory(p.join(iosRunner, 'AlternateIcons'));
  if (altDir.existsSync()) {
    for (final entry in iosSizes.entries) {
      final out = File(p.join(altDir.path, entry.key));
      _writePng(out, master, entry.value);
    }
  }

  // --- Manifest ---
  _patchAndroidManifest(
    manifestPath: manifest,
    name: name,
    mipmapName: mipmapName,
    label: label,
  );
  stdout.writeln('  Manifest patched: $manifest');

  // --- Info.plist ---
  _patchInfoPlist(plistPath: plist, name: name);
  stdout.writeln('  Info.plist patched: $plist');

  // --- Xcode pbxproj ---
  if (!(args['skip-pbxproj'] as bool) && pbxproj != null) {
    final patched = _patchPbxproj(pbxprojPath: pbxproj, name: name);
    if (patched) {
      stdout.writeln('  project.pbxproj patched: $pbxproj');
    } else {
      stdout.writeln(
        '  project.pbxproj: entries already present or could not patch. '
        'Add $name@2x.png / $name@3x.png in Xcode if needed.',
      );
    }
  } else if (pbxproj == null) {
    stdout.writeln(
      '  Skip pbxproj (no path). Add $name@2x.png and $name@3x.png to '
      'Copy Bundle Resources in Xcode.',
    );
  }

  stdout.writeln('');
  stdout.writeln('Done. Next steps:');
  stdout.writeln('  1. flutter clean && flutter run  (full restart required)');
  stdout.writeln('  2. await DynamicAppIconSwitcher().setIcon(\'$name\');');
  stdout.writeln(
    '  3. Add "$name" to your API available_icons / icon_schedule when ready.',
  );
}

bool _allExplicitMissing(ArgResults args) {
  return args['android-res'] == null &&
      args['manifest'] == null &&
      args['ios-runner'] == null &&
      args['plist'] == null;
}

String? _resolvePath({String? explicit, String? exampleDefault}) {
  final raw = explicit ?? exampleDefault;
  if (raw == null) return null;
  return p.normalize(p.absolute(raw));
}

String _findRepoRoot() {
  // tool/add_alternate_icon/bin -> repo root is ../../..
  final scriptDir = File.fromUri(Platform.script).parent;
  return p.normalize(p.join(scriptDir.path, '..', '..', '..'));
}

bool _isValidName(String name) => RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(name);

String _toSnake(String name) {
  final buf = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final ch = name[i];
    final isUpper = ch.toUpperCase() == ch && ch.toLowerCase() != ch;
    if (isUpper && i > 0) buf.write('_');
    buf.write(ch.toLowerCase());
  }
  return buf.toString();
}

Future<img.Image> _loadOrCreateMaster({
  required String? sourcePath,
  required String colorHex,
}) async {
  if (sourcePath != null) {
    final file = File(sourcePath);
    if (!file.existsSync()) {
      throw StateError('Source image not found: $sourcePath');
    }
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode image: $sourcePath');
    }
    // Normalize to square canvas for launcher icons.
    final size = max(decoded.width, decoded.height);
    final canvas = img.Image(width: size, height: size);
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
    final dx = (size - decoded.width) ~/ 2;
    final dy = (size - decoded.height) ~/ 2;
    img.compositeImage(canvas, decoded, dstX: dx, dstY: dy);
    return canvas;
  }

  final color = _parseHexColor(colorHex);
  final canvas = img.Image(width: 1024, height: 1024);
  img.fill(canvas, color: color);
  // Subtle ring so solid placeholders are recognizable.
  for (var t = 0; t < 36; t++) {
    img.drawCircle(
      canvas,
      x: 512,
      y: 512,
      radius: 360 + t,
      color: img.ColorRgba8(255, 255, 255, 220),
    );
  }
  return canvas;
}

img.ColorRgba8 _parseHexColor(String raw) {
  var hex = raw.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length != 6) {
    throw FormatException('Invalid --color "$raw". Use RRGGBB.');
  }
  final value = int.parse(hex, radix: 16);
  return img.ColorRgba8(
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
    255,
  );
}

void _writePng(File out, img.Image master, int size) {
  final resized = img.copyResize(
    master,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
  out.writeAsBytesSync(img.encodePng(resized));
}

void _patchAndroidManifest({
  required String manifestPath,
  required String name,
  required String mipmapName,
  required String label,
}) {
  final file = File(manifestPath);
  var text = file.readAsStringSync();
  final aliasName = '.icons.$name';
  if (text.contains('android:name="$aliasName"') ||
      text.contains("android:name='$aliasName'")) {
    stdout.writeln('  Manifest: alias $aliasName already exists (skipped).');
    return;
  }

  final alias = '''
        <activity-alias
            android:name="$aliasName"
            android:enabled="false"
            android:exported="true"
            android:icon="@mipmap/$mipmapName"
            android:label="$label"
            android:targetActivity=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity-alias>
''';

  final marker = RegExp(
    r'(\s*)(<meta-data\s+android:name="flutterEmbedding")',
  );
  if (!marker.hasMatch(text)) {
    // Fallback: insert before closing </application>
    final appClose = text.lastIndexOf('</application>');
    if (appClose < 0) {
      throw StateError('Could not find </application> in $manifestPath');
    }
    text = text.replaceRange(appClose, appClose, '\n$alias\n    ');
  } else {
    text = text.replaceFirstMapped(marker, (m) => '$alias${m[1]}${m[2]}');
  }
  file.writeAsStringSync(text);
}

void _patchInfoPlist({required String plistPath, required String name}) {
  final file = File(plistPath);
  var text = file.readAsStringSync();
  if (text.contains('<key>$name</key>')) {
    stdout.writeln('  Info.plist: key $name already exists (skipped).');
    return;
  }

  final entry = '''
			<key>$name</key>
			<dict>
				<key>CFBundleIconFiles</key>
				<array>
					<string>$name</string>
				</array>
				<key>UIPrerenderedIcon</key>
				<false/>
			</dict>
''';

  // Insert before the closing of CFBundleAlternateIcons dict.
  // Find CFBundleAlternateIcons then its matching structure — insert before
  // the first "</dict>" that closes alternate icons after the key.
  final altKey = text.indexOf('<key>CFBundleAlternateIcons</key>');
  if (altKey < 0) {
    // Create full CFBundleIcons block before </dict></plist>
    final block = '''
	<key>CFBundleIcons</key>
	<dict>
		<key>CFBundleAlternateIcons</key>
		<dict>
$entry		</dict>
	</dict>
''';
    final end = text.lastIndexOf('</dict>');
    if (end < 0) throw StateError('Invalid Info.plist');
    text = text.replaceRange(end, end, block);
  } else {
    // After <key>CFBundleAlternateIcons</key> there is a <dict>... insert
    // before the </dict> that closes it — approximate by inserting before
    // "</dict>\n\t</dict>\n</dict>\n</plist>" pattern near the end of icons.
    final afterKey = text.indexOf('<dict>', altKey);
    if (afterKey < 0) throw StateError('Malformed CFBundleAlternateIcons');
    // Find closing </dict> for alternate icons: next </dict> at same indent
    // after content. Safer: insert right after <dict> opening of alternate.
    final insertAt = afterKey + '<dict>'.length;
    text = text.replaceRange(insertAt, insertAt, '\n$entry');
  }
  file.writeAsStringSync(text);
}

bool _patchPbxproj({required String pbxprojPath, required String name}) {
  final file = File(pbxprojPath);
  if (!file.existsSync()) return false;
  var text = file.readAsStringSync();
  final file2x = '$name@2x.png';
  final file3x = '$name@3x.png';
  if (text.contains(file2x) && text.contains(file3x)) {
    return false;
  }

  String id() {
    final r = Random();
    final buf = StringBuffer('A');
    const hex = '0123456789ABCDEF';
    for (var i = 0; i < 23; i++) {
      buf.write(hex[r.nextInt(16)]);
    }
    return buf.toString();
  }

  final ref2x = id();
  final build2x = id();
  final ref3x = id();
  final build3x = id();

  // PBXBuildFile
  text = text.replaceFirst(
    '/* End PBXBuildFile section */',
    '\t\t$build2x /* $file2x in Resources */ = {isa = PBXBuildFile; fileRef = $ref2x /* $file2x */; };\n'
        '\t\t$build3x /* $file3x in Resources */ = {isa = PBXBuildFile; fileRef = $ref3x /* $file3x */; };\n'
        '/* End PBXBuildFile section */',
  );

  // PBXFileReference
  text = text.replaceFirst(
    '/* End PBXFileReference section */',
    '\t\t$ref2x /* $file2x */ = {isa = PBXFileReference; lastKnownFileType = image.png; path = "$file2x"; sourceTree = "<group>"; };\n'
        '\t\t$ref3x /* $file3x */ = {isa = PBXFileReference; lastKnownFileType = image.png; path = "$file3x"; sourceTree = "<group>"; };\n'
        '/* End PBXFileReference section */',
  );

  // Runner group children — insert before GeneratedPluginRegistrant.h if present
  if (text.contains('GeneratedPluginRegistrant.h */,')) {
    text = text.replaceFirst(
      '1498D2321E8E86230040F4C2 /* GeneratedPluginRegistrant.h */,',
      '$ref2x /* $file2x */,\n'
          '\t\t\t\t$ref3x /* $file3x */,\n'
          '\t\t\t\t1498D2321E8E86230040F4C2 /* GeneratedPluginRegistrant.h */,',
    );
  }

  // Resources build phase
  final resourcesEnd = text.indexOf(
    '/* End PBXResourcesBuildPhase section */',
  );
  if (resourcesEnd > 0) {
    // Find the Runner Resources files list — look for Assets.xcassets in Resources
    // and append after last png in Resources entry near Main.storyboard block.
    final anchor = 'Assets.xcassets in Resources */,';
    final idx = text.indexOf(anchor);
    if (idx > 0) {
      final lineEnd = text.indexOf('\n', idx);
      text = text.replaceRange(
        lineEnd + 1,
        lineEnd + 1,
        '\t\t\t\t$build2x /* $file2x in Resources */,\n'
            '\t\t\t\t$build3x /* $file3x in Resources */,\n',
      );
    }
  }

  file.writeAsStringSync(text);
  return true;
}
