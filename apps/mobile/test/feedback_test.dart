import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musiclink/app.dart';
import 'package:musiclink/core/api.dart';

void main() {
  const preferences = MethodChannel('org.musiclink.prototype/preferences');
  const share = MethodChannel('org.musiclink.prototype/share');
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      preferences,
      (_) async => <String, String>{},
    );
    messenger.setMockMethodCallHandler(share, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(preferences, null);
      messenger.setMockMethodCallHandler(share, null);
    });
  });

  Future<List<Map<String, dynamic>>> mount(WidgetTester tester) async {
    // A phone, not the default 800×600 test window
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWith(
            (ref) => Api(
              MockClient((request) async {
                sent.add(jsonDecode(request.body) as Map<String, dynamic>);
                return http.Response('{"ok":true}', 200);
              }),
              'https://example.com',
            ),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    return sent;
  }

  testWidgets('the bug button sends a screenshot and the optional email', (
    tester,
  ) async {
    final sent = await mount(tester);

    // The screenshot renders for real, outside the test's fake clock
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.bug_report_outlined));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();
    expect(find.text('Fehler melden'), findsOneWidget);
    expect(find.text('Screenshot entfernen'), findsOneWidget);

    final fields = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, 'Spotify-Link fehlt');
    await tester.enterText(fields.last, 'lena@example.com');
    await tester.pump();
    await tester.tap(find.text('Senden'));
    await tester.pumpAndSettle();
    expect(find.text('Danke! Wir melden uns per Mail.'), findsOneWidget);

    final report = sent.single;
    expect(report['kind'], 'bug');
    expect(report['message'], 'Spotify-Link fehlt');
    expect(report['email'], 'lena@example.com');
    expect(base64.decode(report['screenshot'] as String).take(4), [
      0x89,
      0x50,
      0x4e,
      0x47,
    ], reason: 'PNG');
    expect(report['context'], containsPair('page', '/'));

    // The tap's handler runs outside the fake clock and continues there
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
  });

  testWidgets('the settings take ideas without screenshot and email', (
    tester,
  ) async {
    final sent = await mount(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feedback geben'));
    await tester.pumpAndSettle();
    expect(find.text('Stelle markieren'), findsNothing);

    await tester.enterText(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(TextField),
          )
          .first,
      'Tidal wäre schön',
    );
    await tester.pump();
    await tester.tap(find.text('Senden'));
    await tester.pumpAndSettle();
    expect(find.text('Danke für dein Feedback!'), findsOneWidget);

    final report = sent.single;
    expect(report['kind'], 'idea');
    expect(report.containsKey('screenshot'), isFalse);
    expect(report.containsKey('email'), isFalse);
  });
}
