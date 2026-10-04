import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import 'conversion.dart';

class ConverterScreen extends ConsumerStatefulWidget {
  const ConverterScreen({super.key});
  @override
  ConsumerState<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends ConsumerState<ConverterScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('org.musiclink.prototype/share');
  static const _preferences = MethodChannel(
    'org.musiclink.prototype/preferences',
  );
  String _target = 'appleMusic';
  String _country = 'DE';
  String _savedTarget = 'appleMusic';
  String _savedCountry = 'DE';
  bool _ready = false;
  final _input = TextEditingController();
  Conversion? _conversion;
  String? _selection;
  String? _error;
  bool _loading = false;
  bool _copied = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ready) _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final saved = await _preferences.invokeMapMethod<String, String>(
        'getPreferences',
      );
      if (!mounted) return;
      final previousTarget = _target;
      final previousCountry = _country;
      if (platforms.containsKey(saved?['target']) &&
          (!_ready || saved!['target'] != _savedTarget)) {
        _savedTarget = saved!['target']!;
        _target = _savedTarget;
      }
      if (['DE', 'AT', 'CH', 'US', 'GB'].contains(saved?['country']) &&
          (!_ready || saved!['country'] != _savedCountry)) {
        _savedCountry = saved!['country']!;
        _country = _savedCountry;
      }
      if (_ready &&
          (previousTarget != _target || previousCountry != _country)) {
        _invalidate();
      }
    } on PlatformException {
      if (mounted) _notice('Einstellungen konnten nicht geladen werden.');
    }
  }

  Future<void> _initialize() async {
    await _loadPreferences();
    if (!mounted) return;
    setState(() => _ready = true);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'sharedText') _receive(call.arguments as String);
      });
      _readSharedText();
    }
  }

  Future<void> _savePreferences({bool targetChanged = false}) async {
    _invalidate();
    try {
      await _preferences.invokeMethod('setPreferences', {
        'target': targetChanged ? _target : _savedTarget,
        'country': _country,
      });
      if (targetChanged) _savedTarget = _target;
      _savedCountry = _country;
    } on PlatformException {
      if (mounted) _notice('Einstellungen konnten nicht gespeichert werden.');
    }
  }

  void _invalidate() {
    ++_requestId;
    setState(() {
      _conversion = null;
      _selection = null;
      _copied = false;
      _error = null;
      _loading = false;
    });
  }

  void _sourceChanged(String input) {
    _invalidate();
    setState(() {
      if (input.contains('music.apple.com/') && _target != 'youtubeMusic') {
        _target = 'youtubeMusic';
      } else if (RegExp(r'youtu(?:be\.com|\.be)/').hasMatch(input) &&
          _target == 'youtubeMusic') {
        _target = 'appleMusic';
      }
    });
  }

  Future<void> _readSharedText() async {
    try {
      final text = await _channel.invokeMethod<String>('getSharedText');
      if (text != null && mounted) _receive(text);
    } on PlatformException {
      if (mounted) {
        setState(
          () => _error = 'Der geteilte Link konnte nicht gelesen werden.',
        );
      }
    }
  }

  void _receive(String text) {
    if (!mounted) return;
    _input.text = text;
    _sourceChanged(text);
    _convert();
  }

  Future<void> _convert() async {
    final input = _input.text.trim();
    if (input.isEmpty) return;
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _conversion = null;
      _selection = null;
      _copied = false;
    });
    try {
      final result = await ref
          .read(apiProvider)
          .convert(input, target: _target, country: _country);
      if (!mounted || id != _requestId) return;
      setState(() {
        _conversion = result;
        _selection = result.candidates.length == 1
            ? result.candidates.single.url
            : null;
      });
    } on ApiException catch (error) {
      if (mounted && id == _requestId) setState(() => _error = error.message);
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _selection!));
      if (mounted) setState(() => _copied = true);
    } on PlatformException {
      if (mounted) _notice('Der Link konnte nicht kopiert werden.');
    }
  }

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject()! as RenderBox;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _selection!,
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on PlatformException {
      if (mounted) {
        _notice('Teilen nicht möglich. Kopiere stattdessen den Link.');
      }
    }
  }

  void _notice(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(apiProvider);
    final conversion = _conversion;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MusicLink'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Dein Musikgeschmack.\nIhr Lieblingsplayer.',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Teile Songs zwischen YouTube Music und Apple Music. Ohne Anmeldung.',
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _input,
                  enabled: !_loading && _ready,
                  onChanged: _sourceChanged,
                  maxLength: 4096,
                  maxLines: 2,
                  minLines: 1,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'YouTube-Music- oder Apple-Music-Link',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _convert(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey('target-$_target'),
                        initialValue: _target,
                        decoration: const InputDecoration(
                          labelText: 'Zieldienst',
                        ),
                        items: platforms.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: _loading || !_ready
                            ? null
                            : (value) {
                                setState(() => _target = value!);
                                _savePreferences(targetChanged: true);
                              },
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _country,
                        key: ValueKey('country-$_country'),
                        decoration: const InputDecoration(
                          labelText: 'Apple-Katalog',
                        ),
                        items:
                            const {
                                  'DE': 'Deutschland',
                                  'AT': 'Österreich',
                                  'CH': 'Schweiz',
                                  'US': 'USA',
                                  'GB': 'Großbritannien',
                                }.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                                )
                                .toList(),
                        onChanged: _loading || !_ready
                            ? null
                            : (value) {
                                setState(() => _country = value!);
                                _savePreferences();
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _loading || !_ready ? null : _convert,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(_loading ? 'Suche läuft …' : 'Link umwandeln'),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (conversion != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    conversion.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(conversion.artist),
                  const SizedBox(height: 20),
                  Text(
                    conversion.candidates.length == 1
                        ? 'Vorschlag auf ${platforms[conversion.target]}'
                        : '${conversion.candidates.length} Vorschläge auf ${platforms[conversion.target]}',
                  ),
                  const SizedBox(height: 8),
                  for (final candidate in conversion.candidates)
                    Card(
                      child: ListTile(
                        selected: _selection == candidate.url,
                        leading: candidate.artworkUrl == null
                            ? const Icon(Icons.music_note)
                            : Image.network(
                                candidate.artworkUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.music_note),
                              ),
                        title: Text(candidate.title),
                        subtitle: candidate.details.isEmpty
                            ? null
                            : Text(candidate.details),
                        trailing: Icon(
                          _selection == candidate.url
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        onTap: () => setState(() {
                          _selection = candidate.url;
                          _copied = false;
                        }),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text('Prüfe die gewünschte Aufnahme vor dem Teilen.'),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) => FilledButton.icon(
                      onPressed: _selection == null
                          ? null
                          : () => _share(context),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Weiterteilen'),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selection == null ? null : _copy,
                    icon: const Icon(Icons.copy),
                    label: Text(_copied ? 'Link kopiert' : 'Link kopieren'),
                  ),
                ],
                const SizedBox(height: 32),
                const Text(
                  'Direkt aus deiner Musik-App',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Öffne bei einem Song das Teilen-Menü und wähle MusicLink. Auf dem iPhone findest du die Erweiterung gegebenenfalls unter „Mehr“.',
                ),
                const SizedBox(height: 24),
                Text(
                  'Ohne gespeicherte Song-Historie. Dein Link geht an unseren Dienst. Apple und YouTube liefern Song-Metadaten; bei Spotify zusätzlich ListenBrainz.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
