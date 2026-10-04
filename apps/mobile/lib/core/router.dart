import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/converter/converter_screen.dart';

final routerProvider = Provider((ref) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const ConverterScreen())],
  );
  ref.onDispose(router.dispose);
  return router;
});
