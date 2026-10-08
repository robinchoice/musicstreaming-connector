import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/router.dart';

enum FeedbackKind { bug, idea }

/// Bugs come from the floating button with a screenshot, ideas from the
/// settings. The context is taken now, as the tester saw the screen.
Future<void> showFeedbackSheet(
  BuildContext context,
  WidgetRef ref,
  FeedbackKind kind, {
  Uint8List? screenshot,
}) {
  final size = MediaQuery.sizeOf(context);
  final feedbackContext = {
    'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    'page': ref
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path,
    'device': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    'viewport':
        '${size.width.round()}×${size.height.round()} @${MediaQuery.devicePixelRatioOf(context)}x',
    'errors': [...recentErrors],
  };
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FeedbackSheet(
      kind: kind,
      screenshot: screenshot,
      feedbackContext: feedbackContext,
    ),
  );
}

class FeedbackSheet extends ConsumerStatefulWidget {
  final FeedbackKind kind;
  final Uint8List? screenshot;
  final Map<String, dynamic> feedbackContext;

  const FeedbackSheet({
    super.key,
    required this.kind,
    required this.feedbackContext,
    this.screenshot,
  });

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  final _message = TextEditingController();
  final _email = TextEditingController();
  late Uint8List? _screenshot = widget.screenshot;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _mark() async {
    final marked = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MarkScreen(screenshot: _screenshot!),
      ),
    );
    if (marked != null) setState(() => _screenshot = marked);
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      await ref.read(apiProvider).sendFeedback({
        'kind': widget.kind.name,
        'message': _message.text.trim(),
        if (email.isNotEmpty) 'email': email,
        if (_screenshot != null) 'screenshot': base64Encode(_screenshot!),
        'context': widget.feedbackContext,
      });
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            email.isEmpty
                ? 'Danke für dein Feedback!'
                : 'Danke! Wir melden uns per Mail.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.feedbackContext;
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).hintColor);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text(
            widget.kind == FeedbackKind.bug
                ? 'Fehler melden'
                : 'Feedback geben',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            maxLength: 5000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: widget.kind == FeedbackKind.bug
                  ? 'Was ist passiert? Was hast du erwartet?'
                  : 'Was fehlt dir, was wünschst du dir, was gefällt dir?',
              border: const OutlineInputBorder(),
              counterText: '',
            ),
          ),
          if (_screenshot != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                _screenshot!,
                height: 180,
                fit: BoxFit.contain,
                semanticLabel: 'Screenshot',
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => setState(() => _screenshot = null),
                  child: const Text('Screenshot entfernen'),
                ),
                TextButton(
                  onPressed: _mark,
                  child: const Text('Stelle markieren'),
                ),
              ],
            ),
          ],
          ExpansionTile(
            title: Text(
              'Was mitgeschickt wird',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value) in [
                ('Seite', c['page']),
                ('Gerät', c['device']),
                ('Fenster', c['viewport']),
                (
                  'Letzte Fehler',
                  (c['errors'] as List).isEmpty
                      ? '–'
                      : (c['errors'] as List).join(', '),
                ),
              ])
                Text('$label: $value', style: muted),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            maxLength: 255,
            decoration: const InputDecoration(
              labelText: 'Deine Mail, falls wir uns melden dürfen (freiwillig)',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _sending || _message.text.trim().length < 5
                ? null
                : _send,
            child: const Text('Senden'),
          ),
        ],
      ),
    );
  }
}

/// A frame dragged over the screenshot, drawn into the image so the mail
/// shows it too.
class MarkScreen extends ConsumerStatefulWidget {
  final Uint8List screenshot;
  const MarkScreen({super.key, required this.screenshot});

  @override
  ConsumerState<MarkScreen> createState() => _MarkScreenState();
}

class _MarkScreenState extends ConsumerState<MarkScreen> {
  ui.Image? _image;
  Offset? _start;

  /// Relative to the image, from 0 to 1
  Rect? _rect;

  @override
  void initState() {
    super.initState();
    decodeImageFromList(widget.screenshot).then((image) {
      if (mounted) setState(() => _image = image);
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Offset _relative(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0, 1),
    (local.dy / size.height).clamp(0, 1),
  );

  Future<void> _done() async {
    final image = _image!;
    final size = Size(image.width.toDouble(), image.height.toDouble());
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawImage(image, Offset.zero, Paint())
      ..drawRect(
        Rect.fromLTRB(
          _rect!.left * size.width,
          _rect!.top * size.height,
          _rect!.right * size.width,
          _rect!.bottom * size.height,
        ),
        _framePaint(max(3, size.width / 200)),
      );
    final marked = await recorder.endRecording().toImage(
      image.width,
      image.height,
    );
    final png = await marked.toByteData(format: ui.ImageByteFormat.png);
    marked.dispose();
    if (mounted) Navigator.of(context).pop(png!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0D12),
        foregroundColor: const Color(0xFFF2F0EA),
        title: Text(
          'Zieh einen Rahmen um die Stelle, die nicht stimmt.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: const Color(0xFFF2F0EA)),
        ),
        actions: [
          TextButton(
            onPressed: _rect == null ? null : _done,
            child: const Text('Fertig'),
          ),
        ],
      ),
      body: image == null
          ? const SizedBox()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: AspectRatio(
                  aspectRatio: image.width / image.height,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest;
                      return GestureDetector(
                        onPanStart: (d) => setState(() {
                          _start = _relative(d.localPosition, size);
                          _rect = null;
                        }),
                        onPanUpdate: (d) => setState(
                          () => _rect = Rect.fromPoints(
                            _start!,
                            _relative(d.localPosition, size),
                          ),
                        ),
                        onPanEnd: (_) => setState(() {
                          if (_rect != null &&
                              (_rect!.width < 0.01 || _rect!.height < 0.01)) {
                            _rect = null;
                          }
                        }),
                        child: CustomPaint(
                          foregroundPainter: _FramePainter(_rect),
                          child: Image.memory(
                            widget.screenshot,
                            fit: BoxFit.fill,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

Paint _framePaint(double width) => Paint()
  ..color = const Color(0xFFF2545B)
  ..style = PaintingStyle.stroke
  ..strokeWidth = width;

class _FramePainter extends CustomPainter {
  final Rect? rect;
  const _FramePainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final r = rect;
    if (r == null) return;
    canvas.drawRect(
      Rect.fromLTRB(
        r.left * size.width,
        r.top * size.height,
        r.right * size.width,
        r.bottom * size.height,
      ),
      _framePaint(3),
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.rect != rect;
}
