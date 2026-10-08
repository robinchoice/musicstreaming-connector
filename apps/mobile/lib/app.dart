import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'core/router.dart';
import 'features/feedback/feedback_button.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: appName,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF42633F),
        primary: const Color(0xFF42633F),
        surface: const Color(0xFFFBFCF7),
      ),
      scaffoldBackgroundColor: const Color(0xFFFBFCF7),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      useMaterial3: true,
    ),
    routerConfig: ref.watch(routerProvider),
    builder: (context, child) => FeedbackButton(child: child!),
    debugShowCheckedModeBanner: false,
  );
}
