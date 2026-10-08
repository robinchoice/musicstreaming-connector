import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../feedback/feedback_sheet.dart';
import 'conversion.dart';
import 'share_setup.dart';

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
  String _savedTarget = 'appleMusic';
  bool _ready = false;
  bool _showSetup = false;
  bool _guideOnly = false;
  bool _sharing = false;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final _input = TextEditingController();
  Conversion? _conversion;
  String? _selection;
  String? _error;
  String? _searchUrl;
  bool _loading = false;
  bool _copied = false;
  int _requestId = 0;

  String get _country {
    final region =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    return countries.contains(region) ? region! : 'DE';
  }

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
      if (!_ready) {
        _showSetup = _isIOS && saved?['shareSetupSeen'] != 'true';
      }
      final previousTarget = _target;
      if (platforms.containsKey(saved?['target']) &&
          (!_ready || saved!['target'] != _savedTarget)) {
        _savedTarget = saved!['target']!;
        _target = _destinationForInput(_input.text);
      }
      if (_ready && previousTarget != _target) _invalidate();
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

  Future<void> _savePreferences() async {
    _invalidate();
    try {
      await _preferences.invokeMethod('setPreferences', {'target': _target});
      _savedTarget = _target;
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
      _searchUrl = null;
      _loading = false;
    });
  }

  String _destinationForInput(String input) {
    final targets = targetsFor(input);
    return targets.contains(_savedTarget) ? _savedTarget : targets.first;
  }

  void _sourceChanged(String input) {
    _invalidate();
    setState(() => _target = _destinationForInput(input));
  }

  Future<void> _dismissSetup() async {
    setState(() => _showSetup = false);
    try {
      await _preferences.invokeMethod('dismissShareSetup');
    } on PlatformException {
      if (mounted) _notice('Die Einrichtung konnte nicht gespeichert werden.');
    }
  }

  void _openGuide() => setState(() {
    _guideOnly = true;
    _showSetup = true;
  });

  Future<void> _settings() async {
    var target = _target;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Deine Einstellungen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: target,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Zieldienst'),
                items: _targetItems(),
                onChanged: (value) => target = value!,
              ),
              if (_isIOS) ...[
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openGuide();
                  },
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Favoriten-Anleitung öffnen'),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  showFeedbackSheet(this.context, ref, FeedbackKind.idea);
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Feedback geben'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Einstellungen übernehmen'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || saved != true || target == _target) return;
    final hadResult = _conversion != null;
    setState(() => _target = target);
    await _savePreferences();
    if (mounted && hadResult) _convert();
  }

  List<DropdownMenuItem<String>> _targetItems() => [
    for (final target in targetsFor(_input.text))
      DropdownMenuItem(value: target, child: Text(platforms[target]!)),
  ];

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
    FocusScope.of(context).unfocus();
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _searchUrl = null;
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
        _selection = result.candidates.first.url;
      });
    } on ApiException catch (error) {
      if (mounted && id == _requestId) {
        setState(() {
          _error = error.message;
          _searchUrl = error.searchUrl;
        });
      }
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) setState(() => _copied = true);
    } on PlatformException {
      if (mounted) _notice('Der Link konnte nicht kopiert werden.');
    }
  }

  Future<void> _share(BuildContext buttonContext, String url) async {
    final box = buttonContext.findRenderObject()! as RenderBox;
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: url,
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on PlatformException {
      if (mounted) {
        _notice('Teilen nicht möglich. Kopiere stattdessen den Link.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
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
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_showSetup) {
      return ShareSetup(onDone: _dismissSetup, guideOnly: _guideOnly);
    }
    final conversion = _conversion;
    final selected = conversion?.candidates.firstWhere(
      (candidate) => candidate.url == _selection,
    );
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(conversion == null ? 'MusicLink' : 'Bereit zum Teilen'),
        backgroundColor: Colors.transparent,
        leading: conversion == null
            ? null
            : IconButton(
                tooltip: 'Zurück zum Musiklink',
                onPressed: _sharing ? null : _invalidate,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),
        actions: [
          IconButton(
            tooltip: 'Einstellungen',
            onPressed: _loading || _sharing ? null : _settings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              key: ValueKey(conversion == null ? 'input' : 'result'),
              padding: const EdgeInsets.all(24),
              children: conversion == null
                  ? [
                      Text(
                        'Dein Song.\nIhr Lieblingsplayer.',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Teile Songs zwischen YouTube Music, Apple Music, Spotify und Deezer. Ohne Anmeldung.',
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _input,
                        enabled: !_loading,
                        onChanged: _sourceChanged,
                        maxLength: 4096,
                        maxLines: 2,
                        minLines: 1,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Link aus YouTube Music, Apple Music, Spotify oder Deezer',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _convert(),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey('target-$_target'),
                        initialValue: _target,
                        decoration: const InputDecoration(
                          labelText: 'Teilen als',
                        ),
                        items: _targetItems(),
                        onChanged: _loading
                            ? null
                            : (value) {
                                if (value == _target) return;
                                setState(() => _target = value!);
                                _savePreferences();
                              },
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _loading ? null : _convert,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          _loading ? 'Suche läuft …' : 'Link umwandeln',
                        ),
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
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                      if (_searchUrl != null) ...[
                        const Text(
                          'Teile stattdessen eine Suche nach dem Song.',
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) => FilledButton.icon(
                            onPressed: _sharing
                                ? null
                                : () => _share(context, _searchUrl!),
                            icon: const Icon(Icons.search),
                            label: Text(
                              'Suche auf ${platforms[_target]} teilen',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _sharing ? null : () => _copy(_searchUrl!),
                          icon: const Icon(Icons.copy),
                          label: Text(
                            _copied ? 'Suchlink kopiert' : 'Suchlink kopieren',
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      if (_isIOS)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nächstes Mal direkt teilen',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Hole MusicLink nach vorne ins Teilen-Menü. Dann sparst du dir das Einfügen.',
                              ),
                              TextButton.icon(
                                onPressed: _loading ? null : _openGuide,
                                icon: const Icon(Icons.star_outline),
                                label: const Text('So richtest du es ein'),
                              ),
                            ],
                          ),
                        )
                      else
                        const Text(
                          'Direkt aus deiner Musik-App: Öffne bei einem Song das Teilen-Menü und wähle MusicLink.',
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Ohne gespeicherte Song-Historie. Dein Link geht an unseren Dienst. Apple, YouTube, Spotify und Deezer liefern Song-Metadaten; für Spotify-Treffer zusätzlich ListenBrainz.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ]
                  : [
                      const SizedBox(height: 20),
                      Center(child: _artwork(selected!, 148)),
                      const SizedBox(height: 24),
                      Text(
                        selected.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(conversion.artist, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: _sharing ? null : _settings,
                          icon: const Icon(Icons.music_note, size: 18),
                          label: Text('${platforms[conversion.target]} ⌄'),
                        ),
                      ),
                      if (selected.details.isNotEmpty)
                        Text(
                          selected.details,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      if (conversion.candidates.length > 1)
                        ExpansionTile(
                          title: Text(
                            'Andere Fassungen (${conversion.candidates.length - 1})',
                          ),
                          children: [
                            for (final candidate in conversion.candidates)
                              if (candidate != selected)
                                ListTile(
                                  leading: _artwork(candidate, 48),
                                  title: Text(candidate.title),
                                  subtitle: candidate.details.isEmpty
                                      ? null
                                      : Text(candidate.details),
                                  onTap: _sharing
                                      ? null
                                      : () => setState(() {
                                          _selection = candidate.url;
                                          _copied = false;
                                        }),
                                ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      Builder(
                        builder: (context) => FilledButton.icon(
                          onPressed: _sharing
                              ? null
                              : () => _share(context, selected.url),
                          icon: const Icon(Icons.ios_share),
                          label: Text(
                            'Als ${platforms[conversion.target]}-Link teilen',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _sharing ? null : () => _copy(selected.url),
                        icon: const Icon(Icons.copy),
                        label: Text(_copied ? 'Link kopiert' : 'Link kopieren'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Prüfe die gewünschte Aufnahme vor dem Teilen.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _artwork(Candidate candidate, double size) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: candidate.artworkUrl == null
        ? SizedBox(
            width: size,
            height: size,
            child: const ColoredBox(
              color: Color(0xFFE8EDDF),
              child: Icon(Icons.music_note, size: 32),
            ),
          )
        : Image.network(
            candidate.artworkUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => SizedBox(
              width: size,
              height: size,
              child: const Icon(Icons.music_note),
            ),
          ),
  );
}
