// Renders the app screens for the App Store pictures with made-up data:
//
//   flutter test --dart-define=API_URL=https://songgate.app tool/store_screenshots/store_screenshots_test.dart
//
// writes build/store_screenshots/<locale>-<device>-<screen>.png, which
// compose.py puts under the captions. Not under test/, so `flutter test` skips it.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musiclink/app.dart';
import 'package:musiclink/core/api.dart';

const devices = {
  // Logical size, pixel ratio and safe area of an iPhone 16 Pro Max and a 13" iPad
  'iphone': (size: Size(440, 956), ratio: 3.0, top: 62.0, bottom: 34.0),
  'ipad': (size: Size(1032, 1376), ratio: 2.0, top: 24.0, bottom: 20.0),
};

late HttpServer covers;

Map<String, dynamic> song({required bool album}) => {
  'source': {
    'kind': album ? 'album' : 'song',
    'platform': 'appleMusic',
    'title': album ? 'Nachtfahrt' : 'Sommerregen',
    'artist': 'Die Laternen',
    'url': 'https://music.apple.com/de/song/1',
    'artworkUrl':
        'http://127.0.0.1:${covers.port}/cover-${album ? 'album' : 'song'}.png',
  },
  'sharePath': album ? '/s/album/am/de/2' : '/s/am/de/1',
  'links': {
    'spotify': {
      'url': 'https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC',
      'found': true,
    },
    'appleMusic': {
      'url': 'https://music.apple.com/de/song/1440839417',
      'found': true,
    },
    'youtubeMusic': {
      'url': 'https://music.youtube.com/watch?v=k2lU5b3FvJo',
      'found': true,
    },
    'deezer': {'url': 'https://www.deezer.com/track/3135556', 'found': true},
  },
};

final social = jsonEncode({
  'friends': [
    {'name': 'Lena', 'platform': 'spotify'},
    {'name': 'Jonas', 'platform': 'appleMusic'},
    {'name': 'Mira', 'platform': 'deezer'},
    {'name': 'Tim', 'platform': 'youtubeMusic'},
  ],
  'groups': [
    {
      'name': 'Bandprobe',
      'members': ['Lena', 'Jonas', 'Tim'],
    },
  ],
  'me': {'name': 'Robin', 'platform': 'youtubeMusic'},
});

Future<void> loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(file).readAsBytesSync())),
    );
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const preferences = MethodChannel('org.musiclink.prototype/preferences');
  final shot = GlobalKey();

  setUpAll(() async {
    // Real HTTP, so Image.network loads the covers from the server below
    HttpOverrides.global = null;
    covers = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    covers.listen((request) async {
      final file = File('tool/store_screenshots${request.uri.path}');
      request.response.headers.contentType = ContentType('image', 'png');
      await request.response.addStream(file.openRead());
      await request.response.close();
    });
    final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
    final roboto = '$flutterRoot/bin/cache/artifacts/material_fonts';
    // Stand-ins for SF Pro, which only exists on Apple devices
    for (final family in [
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      '.SF UI Text',
      '.SF UI Display',
      'Roboto',
    ]) {
      await loadFont(family, [
        for (final weight in ['Regular', 'Medium', 'Bold'])
          '$roboto/Roboto-$weight.ttf',
        '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
      ]);
    }
    await loadFont('Noto Color Emoji', [
      '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    ]);
    await loadFont('MaterialIcons', ['$roboto/MaterialIcons-Regular.otf']);
    await loadFont('Bricolage Grotesque', [
      'assets/fonts/BricolageGrotesque.ttf',
    ]);
  });
  tearDownAll(() => covers.close(force: true));

  for (final locale in ['de', 'en']) {
    for (final device in devices.entries) {
      testWidgets('$locale ${device.key}', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.platformDispatcher.localesTestValue = [Locale(locale)];
        final spec = device.value;
        tester.view.physicalSize = spec.size * spec.ratio;
        tester.view.devicePixelRatio = spec.ratio;
        tester.view.padding = FakeViewPadding(
          top: spec.top * spec.ratio,
          bottom: spec.bottom * spec.ratio,
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(preferences, (call) async {
              return switch (call.method) {
                'getSocial' => social,
                'getPreferences' => {'shareSetupSeen': 'true'},
                'getTestMode' => false,
                _ => null,
              };
            });
        var album = false;
        await tester.pumpWidget(
          RepaintBoundary(
            key: shot,
            child: ProviderScope(
              overrides: [
                apiProvider.overrideWith(
                  (ref) => Api(
                    MockClient(
                      (_) async => http.Response.bytes(
                        utf8.encode(jsonEncode(song(album: album))),
                        200,
                      ),
                    ),
                    'https://songgate.app',
                  ),
                ),
              ],
              child: const App(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Load the covers once, so the first picture has them too
        await tester.runAsync(() async {
          final context = shot.currentContext!;
          for (final name in ['song', 'album']) {
            await precacheImage(
              NetworkImage('http://127.0.0.1:${covers.port}/cover-$name.png'),
              context,
            );
          }
        });

        Future<void> capture(String name) async {
          // Covers decode outside the fake clock
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 2)),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 500)),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                shot.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: spec.ratio);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              'build/store_screenshots/$locale-${device.key}-$name.png',
            );
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(png!.buffer.asUint8List());
            // The test fonts have no emoji: compose.py paints the one in the message,
            // [0 for 🎵 or 1 for 💿, left, top, right, bottom]
            final emoji = <List<double>>[];
            for (final element in find.byType(EditableText).evaluate()) {
              final state =
                  (element as StatefulElement).state as EditableTextState;
              final text = state.textEditingValue.text;
              if (!text.startsWith('🎵') && !text.startsWith('💿')) continue;
              final editable = state.renderEditable;
              for (final box in editable.getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 2),
              )) {
                final from = editable.localToGlobal(Offset(box.left, box.top));
                final to = editable.localToGlobal(
                  Offset(box.right, box.bottom),
                );
                emoji.add([
                  if (text.startsWith('💿')) 1 else 0,
                  for (final value in [from.dx, from.dy, to.dx, to.dy])
                    value * spec.ratio,
                ]);
              }
            }
            File(file.path.replaceFirst('.png', '.json'))
                .writeAsStringSync(jsonEncode(emoji));
          });
        }

        Future<void> convert(bool isAlbum) async {
          album = isAlbum;
          await tester.enterText(
            find.byType(TextField),
            'https://music.apple.com/de/song/1',
          );
          await tester.pump();
          await tester.tap(find.text(locale == 'de' ? 'Finden' : 'Find'));
          await tester.pumpAndSettle();
        }

        await convert(false);
        await capture('song');
        await tester.tap(find.byKey(const ValueKey('group-Bandprobe')));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -320));
        await tester.pumpAndSettle();
        await capture('group');
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.pumpAndSettle();
        await convert(true);
        await capture('album');
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.group_outlined));
        await tester.pumpAndSettle();
        await capture('friends');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(minutes: 1));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
