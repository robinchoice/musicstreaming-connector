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

Map<String, dynamic> result({int count = 1, String title = 'Plätscher'}) => {
  'target': 'appleMusic',
  'source': {
    'title': title,
    'artist': 'Paul Kalkbrenner',
    'url': 'https://music.youtube.com/watch?v=UijW9hGpnzc',
  },
  'candidates': List.generate(
    count,
    (i) => {
      'title': title,
      'url': 'https://music.apple.com/de/song/${i + 1}',
      'artworkUrl': null,
    },
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.musiclink.prototype/share');
  const preferences = MethodChannel('org.musiclink.prototype/preferences');
  setUp(() {
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

  test('API uses shared endpoint and preserves Unicode', () async {
    final api = Api(
      MockClient((request) async {
        expect(
          request.url.toString(),
          'https://musiclink.example/api/v1/convert',
        );
        expect(jsonDecode(request.body), {
          'input': 'https://youtu.be/UijW9hGpnzc',
          'target': 'appleMusic',
          'country': 'DE',
        });
        expect(request.headers['content-type'], 'application/json');
        return http.Response.bytes(utf8.encode(jsonEncode(result())), 200);
      }),
      'https://musiclink.example/',
    );
    final conversion = await api.convert('https://youtu.be/UijW9hGpnzc');
    expect(conversion.title, 'Plätscher');
    expect(conversion.candidates.single.title, 'Plätscher');
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
        api.convert('song'),
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
      await expectLater(offline.convert('song'), throwsA(isA<ApiException>()));
      final malformed = Api(
        MockClient((_) async => http.Response('<html>502</html>', 502)),
        'https://example.com',
      );
      await expectLater(
        malformed.convert('song'),
        throwsA(isA<ApiException>()),
      );
    },
  );

  Future<void> mount(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) respond,
  ) async {
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

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/UijW9hGpnzc',
    );
    await tester.tap(find.text('Link umwandeln'));
    await tester.pumpAndSettle();
  }

  testWidgets('one match is preselected and can be copied', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await mount(
      tester,
      (_) async => http.Response.bytes(utf8.encode(jsonEncode(result())), 200),
    );
    await submit(tester);
    expect(find.text('Paul Kalkbrenner'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Weiterteilen'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Weiterteilen'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.scrollUntilVisible(
      find.text('Link kopieren'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Link kopieren'));
    await tester.pumpAndSettle();
    expect(copied, 'https://music.apple.com/de/song/1');
    expect(find.text('Link kopiert'), findsOneWidget);
  });

  testWidgets('multiple releases require explicit selection', (tester) async {
    await mount(
      tester,
      (_) async =>
          http.Response.bytes(utf8.encode(jsonEncode(result(count: 2))), 200),
    );
    await submit(tester);
    await tester.scrollUntilVisible(
      find.text('Weiterteilen'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Weiterteilen'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(ListTile).last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Weiterteilen'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('failed conversion can be retried', (tester) async {
    var calls = 0;
    await mount(
      tester,
      (_) async => ++calls == 1
          ? http.Response(jsonEncode({'error': 'Bitte erneut versuchen'}), 502)
          : http.Response.bytes(utf8.encode(jsonEncode(result())), 200),
    );
    await submit(tester);
    expect(find.text('Bitte erneut versuchen'), findsOneWidget);
    await tester.tap(find.text('Link umwandeln'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte erneut versuchen'), findsNothing);
    expect(find.text('Paul Kalkbrenner'), findsOneWidget);
  });

  testWidgets('cold Android share starts conversion without manual input', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => 'https://youtu.be/UijW9hGpnzc',
        );
    await mount(
      tester,
      (_) async => http.Response.bytes(utf8.encode(jsonEncode(result())), 200),
    );
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
    await tester.tap(find.text('Link umwandeln'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    response.complete(
      http.Response.bytes(utf8.encode(jsonEncode(result())), 200),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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
          : Future.value(
              http.Response.bytes(
                utf8.encode(jsonEncode(result(title: 'New song'))),
                200,
              ),
            ),
    );
    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/UijW9hGpnzc',
    );
    await tester.tap(find.text('Link umwandeln'));
    await tester.pump();
    tester.binding.channelBuffers.push(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('sharedText', 'https://youtu.be/Z19cVpmYIkw'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.text('New song'), findsWidgets);
    old.complete(
      http.Response.bytes(
        utf8.encode(jsonEncode(result(title: 'Old song'))),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old song'), findsNothing);
    expect(find.text('New song'), findsWidgets);
  });
  testWidgets(
    'Apple input chooses YouTube Music and clears stale output when edited',
    (tester) async {
      await mount(tester, (request) async {
        expect(jsonDecode(request.body)['target'], 'youtubeMusic');
        return http.Response.bytes(
          utf8.encode(jsonEncode({...result(), 'target': 'youtubeMusic'})),
          200,
        );
      });
      await tester.enterText(
        find.byType(TextField),
        'https://music.apple.com/de/song/945575419',
      );
      await tester.tap(find.text('Link umwandeln'));
      await tester.pumpAndSettle();
      expect(find.text('Paul Kalkbrenner'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'https://music.apple.com/de/song/123',
      );
      await tester.pumpAndSettle();
      expect(find.text('Paul Kalkbrenner'), findsNothing);
      expect(find.text('Weiterteilen'), findsNothing);
    },
  );

  testWidgets('saved preferences load before an incoming share is converted', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          preferences,
          (_) async => {'target': 'youtubeMusic', 'country': 'AT'},
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => 'https://music.apple.com/de/song/945575419',
        );
    await mount(tester, (request) async {
      expect(jsonDecode(request.body), {
        'input': 'https://music.apple.com/de/song/945575419',
        'target': 'youtubeMusic',
        'country': 'AT',
      });
      return http.Response.bytes(
        utf8.encode(jsonEncode({...result(), 'target': 'youtubeMusic'})),
        200,
      );
    });
    expect(find.text('Paul Kalkbrenner'), findsOneWidget);
  });

  testWidgets('destination changes are persisted for the native extension', (
    tester,
  ) async {
    Map? saved;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(preferences, (call) async {
          if (call.method == 'setPreferences') saved = call.arguments as Map;
          return <String, String>{};
        });
    await mount(
      tester,
      (_) async => http.Response.bytes(utf8.encode(jsonEncode(result())), 200),
    );
    await tester.tap(find.text('Apple Music').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('YouTube Music').last);
    await tester.pumpAndSettle();
    expect(saved, {'target': 'youtubeMusic', 'country': 'DE'});
  });
  for (final pending in [false, true]) {
    testWidgets(
      'resume preserves automatic destination and ${pending ? "pending request" : "results"}',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              preferences,
              (_) async => {'target': 'spotify', 'country': 'DE'},
            );
        final response = Completer<http.Response>();
        await mount(tester, (request) {
          expect(jsonDecode(request.body)['target'], 'youtubeMusic');
          return response.future;
        });
        await tester.enterText(
          find.byType(TextField),
          'https://music.apple.com/de/song/945575419',
        );
        await tester.tap(find.text('Link umwandeln'));
        await tester.pump();
        if (!pending) {
          response.complete(
            http.Response.bytes(
              utf8.encode(jsonEncode({...result(), 'target': 'youtubeMusic'})),
              200,
            ),
          );
          await tester.pumpAndSettle();
        }
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        if (pending) {
          response.complete(
            http.Response.bytes(
              utf8.encode(jsonEncode({...result(), 'target': 'youtubeMusic'})),
              200,
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('Paul Kalkbrenner'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('target-youtubeMusic')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('changing country does not persist an automatic destination', (
    tester,
  ) async {
    Map? saved;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(preferences, (call) async {
          if (call.method == 'setPreferences') saved = call.arguments as Map;
          return {'target': 'appleMusic', 'country': 'DE'};
        });
    await mount(
      tester,
      (_) async => http.Response.bytes(utf8.encode(jsonEncode(result())), 200),
    );
    await tester.enterText(
      find.byType(TextField),
      'https://music.apple.com/de/song/945575419',
    );
    await tester.tap(find.text('Deutschland').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Österreich').last);
    await tester.pumpAndSettle();
    expect(saved, {'target': 'appleMusic', 'country': 'AT'});
  });
}
