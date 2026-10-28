import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../core/api.dart';
import '../../core/brand.dart';
import '../../core/locale.dart';
import '../../core/messages.dart';
import '../feedback/feedback_button.dart';
import '../feedback/feedback_sheet.dart';
import '../friends/friends_bar.dart';
import '../friends/friends_screen.dart';
import '../friends/social.dart';
import '../support/support_screen.dart';
import 'conversion.dart';
import 'share_setup.dart';

class ConverterScreen extends ConsumerStatefulWidget {
  const ConverterScreen({super.key});
  @override
  ConsumerState<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends ConsumerState<ConverterScreen> {
  static const _channel = MethodChannel('org.musiclink.prototype/share');
  static const _preferences = MethodChannel(
    'org.musiclink.prototype/preferences',
  );
  bool _ready = false;
  bool _showSetup = false;
  bool _guideOnly = false;
  bool _sharing = false;
  bool get _isIOS => !kIsWeb && isIOS;
  final _input = TextEditingController();
  Song? _song;
  String? _error;
  bool _loading = false;
  int _requestId = 0;
  // Friends fill the services, the tiles can be tapped on their own
  List<String> _chosen = [];
  List<String> _services = [];

  void _setPeople(List<String> names, List<String> services) {
    setState(() {
      _chosen = names;
      _services = services;
    });
  }

  String get _country {
    final region =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    return countries.contains(region) ? region! : 'DE';
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final saved = await _preferences.invokeMapMethod<String, String>(
        'getPreferences',
      );
      _showSetup = _isIOS && saved?['shareSetupSeen'] != 'true';
    } on PlatformException {
      if (mounted) _notice(ref.read(messagesProvider).preferencesFailed);
    }
    if (!mounted) return;
    setState(() => _ready = true);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'sharedText') _receive(call.arguments as String);
      });
      _readSharedText();
    }
  }

  void _reset() {
    ++_requestId;
    setState(() {
      _song = null;
      _error = null;
      _loading = false;
    });
  }

  Future<void> _dismissSetup() async {
    setState(() => _showSetup = false);
    try {
      await _preferences.invokeMethod('dismissShareSetup');
    } on PlatformException {
      if (mounted) _notice(ref.read(messagesProvider).setupSaveFailed);
    }
  }

  void _openGuide() => setState(() {
    _guideOnly = true;
    _showSetup = true;
  });

  Future<void> _settings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (context, sheetRef, _) {
        final t = sheetRef.watch(messagesProvider);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.settingsTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (_isIOS)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openGuide();
                    },
                    icon: const Icon(Icons.star_outline),
                    label: Text(t.openGuide),
                  ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(this.context).push(
                      MaterialPageRoute(builder: (_) => const FriendsScreen()),
                    );
                  },
                  icon: const Icon(Icons.group_outlined),
                  label: Text(t.friendsAndInvite),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showFeedbackSheet(this.context, ref, FeedbackKind.idea);
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(t.giveFeedback),
                ),
                if (supportEnabled)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(this.context).push(
                        MaterialPageRoute(
                          builder: (_) => const SupportScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.favorite_outline),
                    label: Text(t.support),
                  ),
                SwitchListTile(
                  title: Text(t.testMode),
                  subtitle: Text(t.testModeHint),
                  value: sheetRef.watch(testModeProvider).value ?? false,
                  onChanged: (on) =>
                      ref.read(testModeProvider.notifier).set(on),
                ),
                TextButton.icon(
                  onPressed: () => ref.read(localeProvider.notifier).toggle(),
                  icon: const Icon(Icons.translate),
                  label: Text(t.otherLanguage),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => _openPage('datenschutz', 'privacy'),
                      child: Text(t.privacy),
                    ),
                    TextButton(
                      onPressed: () => _openPage('impressum', 'imprint'),
                      child: Text(t.imprint),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  /// Opens a page of the website in the chosen language.
  void _openPage(String german, String english) {
    final path = ref.read(localeProvider).value == AppLocale.en
        ? english
        : german;
    launchUrl(
      Uri.parse('${apiUrl.replaceFirst(RegExp(r'/+$'), '')}/$path'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _readSharedText() async {
    try {
      final text = await _channel.invokeMethod<String>('getSharedText');
      if (text != null && mounted) _receive(text);
    } on PlatformException {
      if (mounted) {
        setState(
          () => _error = ref.read(messagesProvider).sharedLinkUnreadable,
        );
      }
    }
  }

  void _receive(String text) {
    if (!mounted) return;
    _input.text = text;
    _reset();
    _find();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      _notice(ref.read(messagesProvider).clipboardEmpty);
      return;
    }
    _input.text = text.length > 4096 ? text.substring(0, 4096) : text;
    _find();
  }

  Future<void> _find() async {
    final input = _input.text.trim();
    if (input.isEmpty) return;
    FocusScope.of(context).unfocus();
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final song = await ref.read(apiProvider).song(input, country: _country);
      if (!mounted || id != _requestId) return;
      setState(() => _song = song);
    } on ApiException catch (error) {
      if (mounted && id == _requestId) setState(() => _error = error.message);
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  String _message(Song song) {
    final social = ref.read(socialProvider);
    return friendsMessage(
      song,
      social.friends.where((friend) => _chosen.contains(friend.name)).toList(),
      from: social.me,
      locale: ref.read(localeProvider).value ?? AppLocale.de,
      services: [
        for (final platform in serviceOrder)
          if (_services.contains(platform)) platform,
      ],
    );
  }

  Future<void> _copy(String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) _notice(ref.read(messagesProvider).messageCopied);
    } on PlatformException {
      if (mounted) _notice(ref.read(messagesProvider).copyFailed);
    }
  }

  Future<void> _share(BuildContext buttonContext, String message) async {
    final box = buttonContext.findRenderObject()! as RenderBox;
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on PlatformException {
      if (mounted) {
        _notice(ref.read(messagesProvider).shareFailed);
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
    _channel.setMethodCallHandler(null);
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(apiProvider);
    ref.watch(socialProvider);
    final t = ref.watch(messagesProvider);
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_showSetup) {
      return ShareSetup(onDone: _dismissSetup, guideOnly: _guideOnly);
    }
    final song = _song;
    return Scaffold(
      appBar: AppBar(
        title: const SonggateBrand(),
        backgroundColor: Colors.transparent,
        leading: song == null
            ? null
            : IconButton(
                tooltip: t.backToInput,
                onPressed: _sharing ? null : _reset,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),
        actions: [
          IconButton(
            tooltip: t.settings,
            onPressed: _loading || _sharing ? null : _settings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (song?.artworkUrl != null) _Backdrop(song!.artworkUrl!),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  key: ValueKey(song == null ? 'input' : 'result'),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: song == null
                      ? _start(context, t)
                      : _result(song, t),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _start(BuildContext context, Messages t) {
    final theme = Theme.of(context);
    final source = sourceOf(_input.text);
    final empty = _input.text.trim().isEmpty;
    return [
      Text(t.headline, style: theme.textTheme.headlineLarge),
      const SizedBox(height: 14),
      Text(t.intro, style: theme.textTheme.bodyLarge),
      const SizedBox(height: 26),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: hairlineStrong),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: source == null
                  ? const Icon(Icons.link, color: muted, size: 22)
                  : ServiceLogo(source, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _input,
                enabled: !_loading,
                onChanged: (_) => setState(() => _error = null),
                maxLength: 4096,
                maxLines: 2,
                minLines: 1,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: t.linkHint,
                  hintStyle: const TextStyle(
                    color: Color(0xFF6E6C76),
                    fontSize: 15,
                  ),
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _find(),
              ),
            ),
            const SizedBox(width: 8),
            empty
                ? OutlinedButton(
                    onPressed: _loading ? null : _paste,
                    child: Text(t.paste),
                  )
                : FilledButton(
                    onPressed: _loading ? null : _find,
                    child: Text(t.find),
                  ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
        child: Semantics(
          liveRegion: true,
          child: _loading
              ? Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        t.searching,
                        style: const TextStyle(color: muted),
                      ),
                    ),
                  ],
                )
              : _error != null
              ? Text(_error!, style: const TextStyle(color: errorGlow))
              : source != null
              ? Text.rich(
                  TextSpan(
                    text: t.linkFrom,
                    children: [
                      TextSpan(
                        text: platforms[source],
                        style: const TextStyle(
                          color: text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(color: muted),
                )
              : const SizedBox(height: 20),
        ),
      ),
      const SizedBox(height: 10),
      const Divider(color: hairline),
      const SizedBox(height: 8),
      FriendsBar(
        selected: _chosen,
        services: _services,
        enabled: !_loading,
        onChanged: _setPeople,
      ),
      const SizedBox(height: 28),
      if (_isIOS)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.shareDirectTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(t.shareDirectBody),
              TextButton.icon(
                onPressed: _loading ? null : _openGuide,
                icon: const Icon(Icons.star_outline),
                label: Text(t.shareDirectButton),
              ),
            ],
          ),
        )
      else
        Text(t.shareAndroid),
      const SizedBox(height: 24),
      Text(t.privacyNote, style: theme.textTheme.bodySmall),
      const PleasanceFooter(),
    ];
  }

  List<Widget> _result(Song song, Messages t) {
    final theme = Theme.of(context);
    final social = ref.read(socialProvider);
    final message = _message(song);
    final services = _services.length;
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox.square(
            dimension: 220,
            child: song.artworkUrl == null
                ? const ColoredBox(
                    color: raised,
                    child: Icon(Icons.music_note, size: 64, color: muted),
                  )
                : Image.network(
                    song.artworkUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(color: raised),
                  ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        t.kindFrom(song.album, platforms[song.platform]),
        style: const TextStyle(color: muted),
      ),
      const SizedBox(height: 4),
      Text(song.title, style: theme.textTheme.headlineMedium),
      const SizedBox(height: 4),
      Text(
        song.artist,
        style: const TextStyle(fontSize: 17, color: Color(0xCCF2F0EA)),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: muted,
            padding: EdgeInsets.zero,
          ),
          onPressed: _sharing
              ? null
              : () {
                  _input.clear();
                  _reset();
                },
          child: Text(
            t.otherLink,
            style: const TextStyle(decoration: TextDecoration.underline),
          ),
        ),
      ),
      const SizedBox(height: 4),
      FriendsBar(
        selected: _chosen,
        services: _services,
        enabled: !_sharing,
        onChanged: _setPeople,
      ),
      const SizedBox(height: 12),
      for (var row = 0; row < serviceOrder.length; row += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final platform in serviceOrder.skip(row).take(2)) ...[
                  Expanded(
                    child: _ServiceTile(
                      key: ValueKey('service-$platform'),
                      platform: platform,
                      selected: _services.contains(platform),
                      found: song.found[platform] ?? false,
                      detail: _tileDetail(song, platform, social, t),
                      onTap: _sharing
                          ? null
                          : () => setState(() {
                              _services = _services.contains(platform)
                                  ? _services
                                        .where((other) => other != platform)
                                        .toList()
                                  : [..._services, platform];
                              // No service left means everyone again
                              if (_services.isEmpty) _chosen = [];
                            }),
                    ),
                  ),
                  if (platform != serviceOrder.skip(row).take(2).last)
                    const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ),
      Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x40000000),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              services == 0
                  ? t.hintEveryone
                  : services == 1
                  ? t.hintOne(platforms[_services.first]!, social.me != null)
                  : t.hintSeveral,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SelectableText(message),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) => FilledButton.icon(
                      onPressed: _sharing
                          ? null
                          : () => _share(context, message),
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: Text(t.share),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharing ? null : () => _copy(message),
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(t.copy),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const PleasanceFooter(),
    ];
  }

  String _tileDetail(Song song, String platform, Social social, Messages t) {
    if (song.found[platform] != true) return t.searchOnly;
    final names = social.friends
        .where(
          (friend) =>
              _chosen.contains(friend.name) && friend.platform == platform,
        )
        .map((friend) => friend.name);
    if (names.isNotEmpty) return names.join(', ');
    return platform == song.platform ? t.source : t.found;
  }
}

/// The cover, blurred far behind the result, tints the page.
class _Backdrop extends StatelessWidget {
  final String url;
  const _Backdrop(this.url);

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: Opacity(
        opacity: 0.26,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Image.network(
            url,
            // A tiny decode is enough under this much blur
            cacheWidth: 96,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(),
          ),
        ),
      ),
    ),
  );
}

/// A service in the message: tapped on its own or picked through friends.
class _ServiceTile extends StatelessWidget {
  final String platform;
  final bool selected;
  final bool found;
  final String detail;
  final VoidCallback? onTap;
  const _ServiceTile({
    super.key,
    required this.platform,
    required this.selected,
    required this.found,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: selected ? const Color(0xEB24232A) : const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(selected ? 16.5 : 18),
        border: selected ? null : Border.all(color: hairline),
      ),
      child: Row(
        children: [
          ServiceLogo(platform, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    platforms[platform]!,
                    maxLines: 2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final checked = Stack(
      fit: StackFit.expand,
      children: [
        tile,
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? raised : null,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : hairlineStrong,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 13, color: text)
                : null,
          ),
        ),
      ],
    );
    return Opacity(
      opacity: found ? 1 : 0.6,
      child: Semantics(
        button: true,
        toggled: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: selected
              ? Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    gradient: bandGradient(glow),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: checked,
                )
              : checked,
        ),
      ),
    );
  }
}
