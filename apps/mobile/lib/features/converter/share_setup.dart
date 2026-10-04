import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareSetup extends StatefulWidget {
  const ShareSetup({super.key, required this.onDone, this.guideOnly = false});

  final VoidCallback onDone;
  final bool guideOnly;

  @override
  State<ShareSetup> createState() => _ShareSetupState();
}

class _ShareSetupState extends State<ShareSetup> {
  late bool _guide = widget.guideOnly;
  bool _sharing = false;
  bool _tried = false;

  Future<void> _trySharing(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject()! as RenderBox;
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          uri: Uri.parse('https://music.youtube.com/watch?v=MV_3Dpw-BRY'),
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (mounted) setState(() => _tried = true);
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Öffne bei einem Song in deiner Musik-App das Teilen-Menü und folge dieser Anleitung.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: _guide
            ? IconButton(
                tooltip: 'Zurück',
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: _sharing
                    ? null
                    : widget.guideOnly
                    ? widget.onDone
                    : () => setState(() => _guide = false),
              )
            : null,
        title: Text(_guide ? 'MusicLink griffbereit' : 'MusicLink'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  _guide
                      ? 'EINMAL KURZ EINRICHTEN'
                      : 'WENIGER SUCHEN. MEHR MUSIK.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _guide
                      ? 'Beim nächsten Song\ngleich zur Hand.'
                      : 'Dein Song.\nIhr Lieblingsplayer.',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _guide
                      ? 'Füge MusicLink zu deinen Favoriten im iPhone-Teilen-Menü hinzu.'
                      : 'Teile Musik in dem Dienst, den deine Freunde nutzen. Direkt aus deiner Musik-App.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                if (_guide) ...[
                  for (final step in const [
                    (
                      '1',
                      '„Mehr“ öffnen',
                      'In der Reihe mit den Apps ganz nach rechts wischen.',
                    ),
                    (
                      '2',
                      '„Bearbeiten“ → Plus bei MusicLink',
                      'Damit kommt MusicLink zu deinen Favoriten.',
                    ),
                    (
                      '3',
                      'MusicLink nach oben ziehen',
                      'Über den Griff rechts. Dann auf „Fertig“ tippen.',
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(step.$1),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.$2,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Text(step.$3),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 14),
                        Icon(Icons.link, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('MusicLink')),
                        const Icon(Icons.drag_handle),
                        const Icon(Icons.arrow_upward, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Builder(
                    builder: (context) => FilledButton.icon(
                      onPressed: _sharing ? null : () => _trySharing(context),
                      icon: const Icon(Icons.ios_share),
                      label: Text(
                        _tried
                            ? 'Noch einmal ausprobieren'
                            : 'Mit Beispiel-Song einrichten',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _sharing ? null : widget.onDone,
                    child: Text(
                      _tried ? 'Weiter zur App' : 'Später einrichten',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tried
                        ? 'Du kannst die Anleitung jederzeit wieder öffnen. Deine Favoriten verwaltest du selbst im iOS-Menü.'
                        : 'Die Reihenfolge legst du selbst im iOS-Menü fest.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const Icon(
                              Icons.play_circle_fill,
                              color: Color(0xFFDE3E46),
                              size: 40,
                            ),
                            const Icon(Icons.arrow_forward, size: 18),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.link,
                                size: 32,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            const Icon(Icons.arrow_forward, size: 18),
                            const Icon(
                              Icons.music_note,
                              color: Color(0xFFEC5664),
                              size: 40,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'YouTube Music → MusicLink → Apple Music',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final text in const [
                    'Ohne Anmeldung loslegen',
                    'In deiner Musik-App bleiben',
                    'MusicLink einmal nach vorne holen',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(text)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => setState(() => _guide = true),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Teilen-Menü einrichten'),
                  ),
                  TextButton(
                    onPressed: widget.onDone,
                    child: const Text('Später · direkt ausprobieren'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
