import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../core/brand.dart';
import '../../core/locale.dart';

/// Replaces the app when the API no longer serves this build.
class UpdateScreen extends ConsumerWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(messagesProvider);
    final store = isIOS ? appStoreUrl : playStoreUrl;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SonggateBrand(),
                const SizedBox(height: 28),
                Text(t.updateTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(t.updateBody(appName), style: theme.textTheme.bodyLarge),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => launchUrl(
                    Uri.parse(store),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(t.updateNow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
