import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'core/router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: appName,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF657D46)),
      scaffoldBackgroundColor: const Color(0xFFF5F5F0),
      useMaterial3: true,
    ),
    routerConfig: ref.watch(routerProvider),
    debugShowCheckedModeBanner: false,
  );
}
