import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../../core/locale.dart';
import '../../core/router.dart';
import 'feedback_sheet.dart';

final testModeProvider = AsyncNotifierProvider<TestModeController, bool>(
  TestModeController.new,
);

/// Shows the bug button. On until Songgate goes live as 1.0, then off until
/// someone switches it on in the settings. The choice stays on the device.
class TestModeController extends AsyncNotifier<bool> {
  static const _channel = MethodChannel('org.musiclink.prototype/preferences');

  @override
  Future<bool> build() async {
    try {
      final saved = await _channel.invokeMethod<Object?>('getTestMode');
      if (saved is bool) return saved;
    } on PlatformException {
      // No storage, fall back to the default
    }
    return !live;
  }

  Future<void> set(bool on) async {
    state = AsyncData(on);
    try {
      await _channel.invokeMethod('setTestMode', on);
    } on PlatformException {
      // Kept for this session at least
    }
  }
}

/// A bug button over every screen, sheets included. It takes a screenshot of
/// what is below it and opens the feedback form with it. Drag it aside when
/// it covers something.
class FeedbackButton extends ConsumerStatefulWidget {
  final Widget child;
  const FeedbackButton({super.key, required this.child});

  @override
  ConsumerState<FeedbackButton> createState() => _FeedbackButtonState();
}

class _FeedbackButtonState extends ConsumerState<FeedbackButton> {
  static const _size = 44.0;
  final _screen = GlobalKey();
  Offset? _position;
  bool _open = false;

  Future<Uint8List?> _screenshot() async {
    try {
      final boundary =
          _screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: min(MediaQuery.devicePixelRatioOf(context), 2),
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return png?.buffer.asUint8List();
    } catch (e) {
      debugPrint(
        'Screenshot failed: $e',
      ); // the report still goes out, just without it
      return null;
    }
  }

  Future<void> _report() async {
    if (_open) return;
    setState(() => _open = true);
    final screenshot = await _screenshot();
    final navigator = ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext!;
    if (navigator.mounted) {
      await showFeedbackSheet(
        navigator,
        ref,
        FeedbackKind.bug,
        screenshot: screenshot,
      );
    }
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(testModeProvider).value ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final position =
            _position ??
            Offset(
              constraints.maxWidth - _size - 12,
              constraints.maxHeight * 0.62,
            );
        final left = clampDouble(
          position.dx,
          0,
          max(0.0, constraints.maxWidth - _size),
        );
        final top = clampDouble(
          position.dy,
          padding.top,
          max(padding.top, constraints.maxHeight - _size - padding.bottom),
        );
        return Stack(
          children: [
            RepaintBoundary(key: _screen, child: widget.child),
            if (visible && !_open)
              Positioned(
                left: left,
                top: top,
                child: GestureDetector(
                  onPanUpdate: (details) => setState(
                    () => _position = Offset(left, top) + details.delta,
                  ),
                  // No tooltip: this sits above the navigator and its overlay
                  child: Material(
                    color: const Color(0xFF17171A),
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _report,
                      child: SizedBox.square(
                        dimension: _size,
                        child: Icon(
                          Icons.bug_report_outlined,
                          color: const Color(0xFFF2F0EA),
                          size: 20,
                          semanticLabel: ref.watch(messagesProvider).reportBug,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
