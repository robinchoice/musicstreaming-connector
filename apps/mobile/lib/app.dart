import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'core/brand.dart';
import 'core/router.dart';
import 'features/feedback/feedback_button.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: appName,
    theme: buildTheme(),
    routerConfig: ref.watch(routerProvider),
    builder: (context, child) => FeedbackButton(child: child!),
    debugShowCheckedModeBanner: false,
  );
}
