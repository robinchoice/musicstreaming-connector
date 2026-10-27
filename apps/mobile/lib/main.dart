import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/locale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SentryFlutter.init(
    (options) => options
      ..dsn = const String.fromEnvironment('SENTRY_DSN')
      ..sendDefaultPii = false
      ..maxBreadcrumbs = 0
      ..tracesSampleRate = 0
      ..enableAutoSessionTracking = false,
    appRunner: () async {
      // The language is read before the first frame, so no text flips after the start
      final container = ProviderContainer();
      await container.read(localeProvider.future);
      runApp(
        UncontrolledProviderScope(container: container, child: const App()),
      );
    },
  );
}
