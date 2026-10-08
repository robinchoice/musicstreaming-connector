import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/converter/converter_screen.dart';
import '../features/friends/friends_screen.dart';

final routerProvider = Provider((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ConverterScreen()),
      GoRoute(
        path: '/friend',
        builder: (_, state) => AddFriendScreen(
          name: state.uri.queryParameters['name'],
          service: state.uri.queryParameters['service'],
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
