import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../features/converter/converter_screen.dart';
import '../features/friends/friends_screen.dart';

final routerProvider = Provider((ref) {
  final router = GoRouter(
    // Share pages (/s/…) arrive as App Links and Universal Links, the API reads them like a service link
    redirect: (_, state) => state.uri.path.startsWith('/s/')
        ? Uri(
            path: '/',
            queryParameters: {
              'link': Uri.parse(apiUrl)
                  .replace(path: state.uri.path, query: state.uri.hasQuery ? state.uri.query : null)
                  .toString(),
            },
          ).toString()
        : null,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) =>
            ConverterScreen(link: state.uri.queryParameters['link']),
      ),
      GoRoute(
        path: '/friend',
        builder: (_, state) => AddFriendScreen(
          name: state.uri.queryParameters['name'],
          service: state.uri.queryParameters['service'],
        ),
      ),
      // The invite page songgate.app/f/<service>?name=…
      GoRoute(
        path: '/f/:service',
        builder: (_, state) => AddFriendScreen(
          name: state.uri.queryParameters['name'],
          service: state.pathParameters['service'],
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
