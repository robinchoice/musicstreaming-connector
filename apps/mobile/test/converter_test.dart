import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musiclink/app.dart';
import 'package:musiclink/core/api.dart';
import 'package:musiclink/core/router.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records opened links; `apps` false acts as if no app takes the link.
class FakeLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final bool apps;
  final opened = <(String, PreferredLaunchMode)>[];
  FakeLauncher({this.apps = true});

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add((url, options.mode));
    return apps ||
        options.mode != PreferredLaunchMode.externalNonBrowserApplication;
  }
}

Map<String, dynamic> result({String title = 'Plätscher'}) => {
  'source': {
    'kind': 'song',
    'platform': 'youtubeMusic',
    'title': title,
    'artist': 'Paul Kalkbrenner',
    'url': 'https://music.youtube.com/watch?v=UijW9hGpnzc',
    'artworkUrl': null,
  },
  'sharePath': '/s/yt/UijW9hGpnzc',
  'links': {
    'spotify': {'url': 'https://open.spotify.com/track/1', 'found': true},
    'appleMusic': {'url': 'https://music.apple.com/de/song/1', 'found': true},
    'youtubeMusic': {
      'url': 'https://music.youtube.com/watch?v=UijW9hGpnzc',
      'found': true,
    },
    'deezer': {
      'url': 'https://www.deezer.com/search/Pl%C3%A4tscher',
      'found': false,
    },
    'tidal': {'url': 'https://tidal.com/track/1', 'found': true},
    'amazonMusic': {
      'url': 'https://music.amazon.de/search/Pl%C3%A4tscher',
      'found': false,
    },
  },
};

http.Response ok(Map<String, dynamic> body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.musiclink.prototype/share');
  const preferences = MethodChannel('org.musiclink.prototype/preferences');
  setUp(() {
    // German texts, whatever the machine's language
    TestWidgetsFlutterBinding.instance.platformDispatcher.localesTestValue =
        const [Locale('de', 'DE')];
    addTearDown(
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .clearLocalesTestValue,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(preferences, (_) async => <String, String>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(preferences, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('API uses the shared endpoint and preserves Unicode', () async {
    final api = Api(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/song');
        expect(request.url.queryParameters, {
          'input': 'https://youtu.be/UijW9hGpnzc',
          'country': 'DE',
        });
        return ok(result());
      }),
      'https://musiclink.example/',
    );
    final song = await api.song('https://youtu.be/UijW9hGpnzc');
    expect(song.title, 'Plätscher');
    expect(song.platform, 'youtubeMusic');
    expect(song.found['deezer'], isFalse);
  });

  test(
    'API exposes upstream error and handles offline or malformed responses',
    () async {
      final api = Api(
        MockClient(
          (_) async =>
              http.Response(jsonEncode({'error': 'Kein Treffer'}), 422),
        ),
        'https://example.com',
      );
      await expectLater(
        api.song('song'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Kein Treffer',
          ),
        ),
      );
      final offline = Api(
        MockClient((_) async => throw http.ClientException('offline')),
        'https://example.com',
      );
      await expectLater(offline.song('song'), throwsA(isA<ApiException>()));
      final malformed = Api(
        MockClient((_) async => http.Response('<html>502</html>', 502)),
        'https://example.com',
      );
      await expectLater(malformed.song('song'), throwsA(isA<ApiException>()));
    },
  );

  Future<void> mount(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) respond,
  ) async {
    // A tall phone, so the whole result is built without scrolling
    tester.view.physicalSize = const Size(1170, 4500);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWith(
            (ref) => Api(MockClient(respond), 'https://example.com'),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an outdated build shows only the update screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [updateRequiredProvider.overrideWith((ref) async => true)],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Update nötig'), findsOneWidget);
    expect(find.text('Jetzt aktualisieren'), findsOneWidget);
    expect(find.text('Einfügen'), findsNothing);
  });

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/UijW9hGpnzc',
    );
    await tester.pump();
    await tester.tap(find.text('Finden'));
    await tester.pumpAndSettle();
  }

  Future<String?> copyMessage(WidgetTester tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    await tester.scrollUntilVisible(
      find.text('Kopieren'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kopieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kopieren'));
    await tester.pumpAndSettle();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    return copied;
  }

  testWidgets('the result shows every service and one link for all', (
    tester,
  ) async {
    await mount(tester, (_) async => ok(result()));
    await submit(tester);
    expect(find.text('Paul Kalkbrenner'), findsOneWidget);
    expect(find.text('Song aus YouTube Music'), findsOneWidget);
    for (final platform in [
      'spotify',
      'appleMusic',
      'youtubeMusic',
      'deezer',
      'tidal',
      'amazonMusic',
    ]) {
      expect(find.byKey(ValueKey('service-$platform')), findsOneWidget);
    }
    expect(find.text('Quelle'), findsOneWidget);
    expect(find.text('Nur Suche'), findsNWidgets(2));
    expect(
      await copyMessage(tester),
      '🎵 Plätscher – Paul Kalkbrenner\nhttp://localhost:3000/s/yt/UijW9hGpnzc\n\nGeteilt mit localhost:3000',
    );
  });

  testWidgets('tapped services get one line each', (tester) async {
    await mount(tester, (_) async => ok(result()));
    await submit(tester);
    await tester.tap(find.byKey(const ValueKey('service-spotify')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('service-appleMusic')));
    await tester.pumpAndSettle();
    expect(
      await copyMessage(tester),
      '🎵 Plätscher – Paul Kalkbrenner\n'
      'Spotify: https://open.spotify.com/track/1\n'
      'Apple Music: https://music.apple.com/de/song/1\n'
      'Andere: http://localhost:3000/s/yt/UijW9hGpnzc\n\nGeteilt mit localhost:3000',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pick-all')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('pick-all')));
    await tester.pumpAndSettle();
    expect(
      await copyMessage(tester),
      '🎵 Plätscher – Paul Kalkbrenner\nhttp://localhost:3000/s/yt/UijW9hGpnzc\n\nGeteilt mit localhost:3000',
    );
  });

  for (final apps in [true, false]) {
    testWidgets('a tapped service opens in its app (installed: $apps)', (
      tester,
    ) async {
      final launcher = FakeLauncher(apps: apps);
      final previous = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      await mount(tester, (_) async => ok(result()));
      await submit(tester);
      expect(find.byKey(const ValueKey('open-spotify')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('service-spotify')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('In Spotify öffnen'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('In Spotify öffnen'));
      await tester.pumpAndSettle();
      expect(launcher.opened, [
        (
          'https://open.spotify.com/track/1',
          PreferredLaunchMode.externalNonBrowserApplication,
        ),
        if (!apps)
          (
            'https://open.spotify.com/track/1',
            PreferredLaunchMode.externalApplication,
          ),
      ]);
    });
  }

  testWidgets('a failed lookup can be retried', (tester) async {
    var calls = 0;
    await mount(
      tester,
      (_) async => ++calls == 1
          ? http.Response(jsonEncode({'error': 'Bitte erneut versuchen'}), 502)
          : ok(result()),
    );
    await submit(tester);
    expect(find.text('Bitte erneut versuchen'), findsOneWidget);
    await tester.tap(find.text('Finden'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte erneut versuchen'), findsNothing);
    expect(find.text('Paul Kalkbrenner'), findsOneWidget);
  });

  testWidgets('close clears the result and the link', (tester) async {
    await mount(tester, (_) async => ok(result()));
    await submit(tester);
    await tester.tap(find.byTooltip('Anderer Link'));
    await tester.pumpAndSettle();
    expect(find.text('Paul Kalkbrenner'), findsNothing);
    expect(find.text('Einfügen'), findsOneWidget);
  });

  testWidgets('cold Android share starts the lookup without manual input', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => {'text': 'https://youtu.be/UijW9hGpnzc'},
        );
    await mount(tester, (_) async => ok(result()));
    expect(find.text('Paul Kalkbrenner'), findsOneWidget);
  });

  testWidgets(
    'starts in the device language, the settings switch it and the choice stays',
    (tester) async {
      tester.platformDispatcher.localesTestValue = const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ];
      String? saved;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(preferences, (call) async {
            if (call.method == 'getLocale') return saved;
            if (call.method == 'setLocale') saved = call.arguments as String;
            return null;
          });
      final languages = <String?>[];
      await mount(tester, (request) async {
        languages.add(request.headers['accept-language']);
        return ok(result());
      });
      await tester.enterText(
        find.byType(TextField),
        'https://youtu.be/UijW9hGpnzc',
      );
      await tester.pump();
      await tester.tap(find.text('Find'));
      await tester.pumpAndSettle();
      expect(languages, ['en']);
      expect(find.text('Song from YouTube Music'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Deutsch'));
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      expect(saved, 'de');
      expect(find.text('Song aus YouTube Music'), findsOneWidget);

      // A fresh scope is what the app gets after a restart
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            apiProvider.overrideWith(
              (ref) => Api(
                MockClient((_) async => ok(result())),
                'https://example.com',
              ),
            ),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Einfügen'), findsOneWidget);
    },
  );

  testWidgets('the device region picks the catalogue', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('de', 'AT');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await mount(tester, (request) async {
      expect(request.url.queryParameters['country'], 'AT');
      return ok(result());
    });
    await submit(tester);
    expect(find.text('Paul Kalkbrenner'), findsOneWidget);
  });

  testWidgets('dismissing the screen while a request is pending is safe', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    await mount(tester, (_) => response.future);
    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/UijW9hGpnzc',
    );
    await tester.pump();
    await tester.tap(find.text('Finden'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    response.complete(ok(result()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Direct Share friend gets their link in the share sheet', (
    tester,
  ) async {
    const share = MethodChannel('dev.fluttercommunity.plus/share');
    Map? params;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(share, (call) async {
        params = call.arguments as Map;
        return '';
      })
      ..setMockMethodCallHandler(
        preferences,
        (call) async => call.method == 'getSocial'
            ? jsonEncode({
                'friends': [
                  {'name': 'Alex', 'platform': 'spotify'},
                  {'name': 'Kim', 'platform': 'deezer'},
                ],
              })
            : <String, String>{},
      )
      ..setMockMethodCallHandler(
        channel,
        (call) async => {
          'text': 'https://youtu.be/UijW9hGpnzc',
          'to': 'friend:Alex',
        },
      );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(share, null),
    );
    await mount(tester, (_) async => ok(result()));
    final text = params?['text'] as String;
    expect(text, contains('https://open.spotify.com/track/1'));
    expect(text, isNot(contains('deezer')));
    expect(text, isNot(contains('/s/yt/')));
  });

  testWidgets('a share page link opens its song and offers the sender', (
    tester,
  ) async {
    String? saved;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(preferences, (call) async {
          if (call.method == 'setSocial') saved = call.arguments as String;
          return call.method == 'getSocial' ? null : <String, String>{};
        });
    final inputs = <String?>[];
    await mount(tester, (request) async {
      inputs.add(request.url.queryParameters['input']);
      return ok(result());
    });
    ProviderScope.containerOf(tester.element(find.byType(App)))
        .read(routerProvider)
        .go('/s/yt/UijW9hGpnzc?from=Lea&service=deezer');
    await tester.pumpAndSettle();
    expect(inputs, ['http://localhost:3000/s/yt/UijW9hGpnzc']);
    expect(find.text('Plätscher'), findsOneWidget);
    expect(find.text('Lea hört auf Deezer'), findsOneWidget);
    await tester.tap(find.text('Lea speichern'));
    await tester.pumpAndSettle();
    expect(jsonDecode(saved!)['friends'], [
      {'name': 'Lea', 'platform': 'deezer'},
    ]);
  });

  testWidgets('an invite page link opens the invite', (tester) async {
    await mount(tester, (_) async => ok(result()));
    ProviderScope.containerOf(tester.element(find.byType(App)))
        .read(routerProvider)
        .go('/f/spotify?name=Lea');
    await tester.pumpAndSettle();
    expect(find.text('Lea hört auf Spotify'), findsOneWidget);
  });

  testWidgets('a new Android share wins over an older pending request', (
    tester,
  ) async {
    final old = Completer<http.Response>();
    var calls = 0;
    await mount(
      tester,
      (_) => ++calls == 1
          ? old.future
          : Future.value(ok(result(title: 'New song'))),
    );
    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/UijW9hGpnzc',
    );
    await tester.pump();
    await tester.tap(find.text('Finden'));
    await tester.pump();
    tester.binding.channelBuffers.push(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('sharedText', {
          'text': 'https://youtu.be/Z19cVpmYIkw',
        }),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.text('New song'), findsWidgets);
    old.complete(ok(result(title: 'Old song')));
    await tester.pumpAndSettle();
    expect(find.text('Old song'), findsNothing);
    expect(find.text('New song'), findsWidgets);
  });

  testWidgets(
    'iOS setup can be skipped, stays dismissed, and can be reopened',
    (tester) async {
      var seen = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(preferences, (call) async {
            if (call.method == 'dismissShareSetup') seen = true;
            return {'shareSetupSeen': seen.toString()};
          });
      await mount(tester, (_) async => ok(result()));
      await tester.scrollUntilVisible(find.text('Teilen-Menü einrichten'), 250);
      expect(find.text('Teilen-Menü einrichten'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Später · direkt ausprobieren'),
        250,
      );
      await tester.tap(find.text('Später · direkt ausprobieren'));
      await tester.pumpAndSettle();
      expect(seen, isTrue);
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, (_) async => ok(result()));
      expect(find.text('Teilen-Menü einrichten'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('So richtest du es ein'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('So richtest du es ein'));
      await tester.pumpAndSettle();
      expect(find.text('„Mehr“ öffnen'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'example opens the native share sheet without claiming favorite status',
    (tester) async {
      const share = MethodChannel('dev.fluttercommunity.plus/share');
      Map? params;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(share, (call) async {
            params = call.arguments as Map;
            return '';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(share, null),
      );
      await mount(tester, (_) async => ok(result()));
      await tester.scrollUntilVisible(find.text('Teilen-Menü einrichten'), 250);
      await tester.tap(find.text('Teilen-Menü einrichten'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Mit Beispiel-Song einrichten'),
        250,
      );
      await tester.tap(find.text('Mit Beispiel-Song einrichten'));
      await tester.pumpAndSettle();
      expect(params?['uri'], 'https://music.youtube.com/watch?v=MV_3Dpw-BRY');
      expect(params?['originWidth'], greaterThan(0));
      expect(find.text('Weiter zur App'), findsOneWidget);
      expect(
        find.textContaining('Deine Favoriten verwaltest du selbst'),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets('input, in-flight lookup and selection survive live resizing', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var requests = 0;
    await mount(tester, (_) {
      requests++;
      return response.future;
    });
    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/UijW9hGpnzc',
    );
    tester.view.devicePixelRatio = 1;
    for (final size in [
      const Size(320, 640),
      const Size(1024, 768),
      const Size(640, 320),
    ]) {
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(
        left: 24,
        right: 24,
        bottom: 20,
      );
      await tester.pumpAndSettle();
      // In a short landscape window the field may sit below the fold
      final field = find.text(
        'https://youtu.be/UijW9hGpnzc',
        skipOffstage: false,
      );
      expect(field, findsOneWidget);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Finden'));
    await tester.pump();
    tester.view.physicalSize = const Size(768, 1024);
    await tester.pump();
    response.complete(ok(result()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('service-spotify')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('service-spotify')));
    await tester.pumpAndSettle();
    for (final size in [
      const Size(320, 640),
      const Size(1024, 768),
      const Size(640, 320),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(requests, 1);
    expect(
      await copyMessage(tester),
      contains('https://open.spotify.com/track/1'),
    );
  });

  testWidgets('update remains reachable in a short window', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 240);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [updateRequiredProvider.overrideWith((ref) async => true)],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Jetzt aktualisieren'));
    expect(find.text('Jetzt aktualisieren').hitTestable(), findsOneWidget);
  });
}
