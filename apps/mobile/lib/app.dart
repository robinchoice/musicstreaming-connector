import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'core/api.dart';
import 'core/brand.dart';
import 'core/router.dart';
import 'features/feedback/feedback_button.dart';
import 'features/update/update_screen.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: appName,
    theme: buildTheme(),
    routerConfig: ref.watch(routerProvider),
    builder: (context, child) => ref.watch(updateRequiredProvider).value == true
        ? const UpdateScreen()
        : FeedbackButton(child: child!),
    debugShowCheckedModeBanner: false,
  );
}
