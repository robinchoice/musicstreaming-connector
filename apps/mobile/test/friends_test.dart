import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musiclink/app.dart';
import 'package:musiclink/core/api.dart';
import 'package:musiclink/core/messages.dart';
import 'package:musiclink/core/router.dart';
import 'package:musiclink/features/converter/conversion.dart';
import 'package:musiclink/features/friends/friends_screen.dart';
import 'package:musiclink/features/friends/social.dart';
import 'package:qr_flutter/qr_flutter.dart';

final song = Song.fromJson({
  'source': {
    'platform': 'youtubeMusic',
    'title': 'Savior',
    'artist': 'RHCP',
    'url': 'https://music.youtube.com/watch?v=UijW9hGpnzc',
    'artworkUrl': null,
  },
  'sharePath': '/s/yt/UijW9hGpnzc',
  'links': {
    'youtubeMusic': {
      'url': 'https://music.youtube.com/watch?v=UijW9hGpnzc',
      'found': true,
    },
    'appleMusic': {'url': 'https://music.apple.com/de/song/1', 'found': true},
    'spotify': {'url': 'https://open.spotify.com/track/x', 'found': true},
    'deezer': {'url': 'https://www.deezer.com/search/Savior', 'found': false},
  },
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const preferences = MethodChannel('org.musiclink.prototype/preferences');
  String? stored;

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
    stored = jsonEncode({
      'friends': [
        {'name': 'Lisa', 'platform': 'spotify'},
        {'name': 'Jonas', 'platform': 'appleMusic'},
      ],
      'groups': [],
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(preferences, (call) async {
          if (call.method == 'getSocial') return stored;
          if (call.method == 'setSocial') stored = call.arguments as String;
          if (call.method == 'getPreferences') {
            return {'target': 'appleMusic', 'shareSetupSeen': 'true'};
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(preferences, null),
  );

  test('message has one link per service and the share page for others', () {
    expect(
      friendsMessage(song, const [Friend('Lisa', 'spotify')]),
      '🎵 Savior – RHCP\nhttps://open.spotify.com/track/x\n\nGeteilt mit localhost:3000',
    );
    expect(
      friendsMessage(song, const [
        Friend('Lisa', 'spotify'),
        Friend('Jonas', 'appleMusic'),
        Friend('Ben', 'spotify'),
      ]),
      '🎵 Savior – RHCP\n'
      'Spotify (Lisa, Ben): https://open.spotify.com/track/x\n'
      'Apple Music (Jonas): https://music.apple.com/de/song/1\n'
      'Andere: http://localhost:3000/s/yt/UijW9hGpnzc\n\nGeteilt mit localhost:3000',
    );
    expect(
      friendsMessage(song, const [
        Friend('Lisa', 'spotify'),
        Friend('Jonas', 'appleMusic'),
      ], from: const Friend('Robin Ö', 'youtubeMusic')).split('\n')[3],
      'Andere: http://localhost:3000/s/yt/UijW9hGpnzc?from=Robin+%C3%96&service=youtube',
    );
    expect(
      friendsMessage(song, const [
        Friend('Lisa', 'spotify'),
      ], from: const Friend('Robin', 'deezer')),
      '🎵 Savior – RHCP\n'
      'https://open.spotify.com/track/x\n'
      'Alle Dienste: http://localhost:3000/s/yt/UijW9hGpnzc?from=Robin&service=deezer\n\nGeteilt mit localhost:3000',
    );
    final album = Song.fromJson({
      'source': {
        'kind': 'album',
        'title': 'Random Access Memories',
        'artist': 'Daft Punk',
      },
      'sharePath': '/s/album/dz/6575789',
      'links': {
        'deezer': {'url': 'https://www.deezer.com/album/6575789'},
      },
    });
    expect(
      friendsMessage(album, const [Friend('Lisa', 'deezer')]),
      '💿 Random Access Memories – Daft Punk\nhttps://www.deezer.com/album/6575789\n\nGeteilt mit localhost:3000',
    );
    // A show without publisher; TIDAL has no podcasts, its friends get the share page
    final podcast = Song.fromJson({
      'source': {'kind': 'podcast', 'title': 'The Daily', 'artist': ''},
      'sharePath': '/s/podcast/dz/52913',
      'links': {
        'appleMusic': {'url': 'https://podcasts.apple.com/de/podcast/id1'},
        'deezer': {'url': 'https://www.deezer.com/show/52913'},
        'tidal': {'url': 'https://tidal.com/search?q=The+Daily'},
      },
      'apps': [
        {'name': 'Overcast', 'url': 'https://overcast.fm/itunes1'},
      ],
    });
    expect(podcast.apps.single.name, 'Overcast');
    expect(servicesFor(podcast.kind), isNot(contains('tidal')));
    expect(
      friendsMessage(podcast, const [
        Friend('Lisa', 'appleMusic'),
        Friend('Ben', 'tidal'),
        Friend('Jo', 'deezer'),
      ]),
      '🎙️ The Daily\n'
      'Apple Podcasts (Lisa): https://podcasts.apple.com/de/podcast/id1\n'
      'Deezer (Jo): https://www.deezer.com/show/52913\n'
      'Andere: http://localhost:3000/s/podcast/dz/52913\n\nGeteilt mit localhost:3000',
    );
    expect(
      friendsMessage(podcast, const [Friend('Ben', 'tidal')]),
      '🎙️ The Daily\nhttp://localhost:3000/s/podcast/dz/52913\n\nGeteilt mit localhost:3000',
    );
    // Group chats: no service means the share page only, tapped services need no friends
    expect(
      friendsMessage(song, const [], services: const []),
      '🎵 Savior – RHCP\nhttp://localhost:3000/s/yt/UijW9hGpnzc\n\nGeteilt mit localhost:3000',
    );
    expect(
      friendsMessage(
        song,
        const [Friend('Lisa', 'spotify')],
        services: const ['spotify', 'appleMusic'],
      ),
      '🎵 Savior – RHCP\n'
      'Spotify (Lisa): https://open.spotify.com/track/x\n'
      'Apple Music: https://music.apple.com/de/song/1\n'
      'Andere: http://localhost:3000/s/yt/UijW9hGpnzc\n\nGeteilt mit localhost:3000',
    );
    // In English, the same as friendsMessage in packages/shared
    expect(
      friendsMessage(
        song,
        const [Friend('Lisa', 'spotify')],
        services: const ['spotify', 'appleMusic'],
        locale: AppLocale.en,
      ).split('\n').last,
      'Shared with localhost:3000',
    );
    expect(
      friendsMessage(
        song,
        const [Friend('Lisa', 'spotify')],
        from: const Friend('Robin', 'deezer'),
        locale: AppLocale.en,
      ).split('\n')[2],
      'All services: http://localhost:3000/s/yt/UijW9hGpnzc?from=Robin&service=deezer',
    );
  });

  testWidgets('picking friends picks their services for one message', (
    tester,
  ) async {
    final requests = <String>[];
    tester.view.physicalSize = const Size(1170, 4500);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWith(
            (ref) => Api(
              MockClient((request) async {
                requests.add(request.url.path);
                final body = {
                  'source': {
                    'kind': 'song',
                    'platform': 'youtubeMusic',
                    'title': 'Savior',
                    'artist': 'RHCP',
                    'url': 'https://music.youtube.com/watch?v=UijW9hGpnzc',
                    'artworkUrl': null,
                  },
                  'sharePath': '/s/yt/UijW9hGpnzc',
                  'links': {
                    for (final platform in platforms.keys)
                      platform: {
                        'url': 'https://$platform.example/1',
                        'found': true,
                      },
                  },
                };
                return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
              }),
              'https://example.com',
            ),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/UijW9hGpnzc',
    );
    await tester.pump();
    await tester.tap(find.text('Finden'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('friend-Lisa')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('friend-Jonas')));
    await tester.pumpAndSettle();
    expect(requests, ['/api/v1/song']);
    expect(find.text('Lisa'), findsWidgets);
    expect(
      find.textContaining('Spotify (Lisa): https://spotify.example/1'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Apple Music (Jonas): https://appleMusic.example/1'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Als Gruppe speichern'),
      100,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      ),
    );
    expect(find.text('Als Gruppe speichern'), findsOneWidget);
  });

  testWidgets('an invite link saves the friend', (tester) async {
    stored = null;
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const App();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/friend?name=Robin&service=deezer');
    await tester.pumpAndSettle();
    expect(find.text('Robin hört auf Deezer'), findsOneWidget);
    await tester.tap(find.text('Robin speichern'));
    await tester.pumpAndSettle();
    expect(jsonDecode(stored!)['friends'], [
      {'name': 'Robin', 'platform': 'deezer'},
    ]);
    expect(find.text('Robin hört auf Deezer'), findsNothing);
  });

  testWidgets('the own invite shows as a QR code', (tester) async {
    stored = jsonEncode({
      'friends': [],
      'groups': [],
      'me': {'name': 'Robin', 'platform': 'deezer'},
    });
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FriendsScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einladung als QR-Code zeigen'));
    await tester.pumpAndSettle();
    expect(find.text('Robin · Deezer'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final size in [const Size(320, 280), const Size(1024, 768)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Fertig'));
      expect(find.text('Fertig').hitTestable(), findsOneWidget);
    }
  });
  testWidgets('invite stays usable in a short window and after resizing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 280);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AddFriendScreen(name: 'Alex', service: 'spotify'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Alex speichern'));
    expect(find.text('Alex speichern').hitTestable(), findsOneWidget);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    expect(find.text('Alex hört auf Spotify'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('friend dialog scrolls above the keyboard without losing input', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 360);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FriendsScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Freund von Hand hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alex');
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    expect(find.text('Alex'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invite popover uses the button bounds after dialog resize', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.reset);
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
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FriendsScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meine Einladung teilen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alex');
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(params?['originX'], greaterThanOrEqualTo(0));
    expect(
      (params?['originX'] as num) + (params?['originWidth'] as num),
      lessThanOrEqualTo(320),
    );
    expect(params?['originWidth'], greaterThan(0));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
