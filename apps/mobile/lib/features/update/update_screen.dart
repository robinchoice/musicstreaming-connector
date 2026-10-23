import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../core/brand.dart';

/// Replaces the app when the API no longer serves this build.
class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                Text('Update nötig', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  'Diese Version von $appName ist zu alt. Aktualisiere die App, um weiter Songs zu teilen.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => launchUrl(
                    Uri.parse(store),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Jetzt aktualisieren'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
