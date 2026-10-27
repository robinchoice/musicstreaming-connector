import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config.dart';
import 'locale.dart';

// Signal colours from starter's DESIGN.md: the same in every product, never the product colour.
// Filled counters take glow, text and lines on the light ground take deep.
const errorGlow = Color(0xFFF2545B);
const errorDeep = Color(0xFFB3262D);

const glow = [
  Color(0xFFF2545B),
  Color(0xFFFB8C45),
  Color(0xFFF2C14E),
  Color(0xFF6CCF8E),
  Color(0xFF46BFE0),
  Color(0xFF8E92F8),
  Color(0xFFC39BF2),
];
const deep = [
  Color(0xFFB3262D),
  Color(0xFFA8461A),
  Color(0xFF876008),
  Color(0xFF1D6A44),
  Color(0xFF156A88),
  Color(0xFF3B3EA8),
  Color(0xFF6A33A0),
];

const background = Color(0xFF0E0D12);
const surface = Color(0xFF16151B);
const raised = Color(0xFF201F25);
const text = Color(0xFFF2F0EA);
const muted = Color(0xFF9A98A3);
const hairline = Color(0x12FFFFFF);
const hairlineStrong = Color(0x24FFFFFF);
const ink = Color(0xFF17171A);
const displayFont = 'Bricolage Grotesque';
const _radius = BorderRadius.all(Radius.circular(14));
const _pill = BorderRadius.all(Radius.circular(999));

Color bandColor(double position, List<Color> tones) {
  final p = position.clamp(1.0, 7.0);
  final i = math.min(5, (p - 1).floor());
  return Color.lerp(tones[i], tones[i + 1], p - 1 - i)!;
}

LinearGradient bandGradient(List<Color> tones) => LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [
    bandColor(appBand.from, tones),
    bandColor((appBand.from + appBand.to) / 2, tones),
    bandColor(appBand.to, tones),
  ],
);

ThemeData buildTheme() {
  final accent = bandColor((appBand.from + appBand.to) / 2, glow);
  final base = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: ink,
      primaryContainer: raised,
      onPrimaryContainer: text,
      surface: background,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: raised,
      outline: hairline,
      outlineVariant: hairline,
      error: errorGlow,
      onError: ink,
    ),
    scaffoldBackgroundColor: background,
  );
  TextStyle? display(TextStyle? style) => style?.copyWith(
    fontFamily: displayFont,
    fontWeight: FontWeight.w800,
    fontVariations: const [
      FontVariation('wdth', 80),
      FontVariation('wght', 780),
    ],
    letterSpacing: -0.8,
    height: 1.05,
  );
  final typography = base.textTheme;
  return base.copyWith(
    textTheme: typography.copyWith(
      displayLarge: display(typography.displayLarge),
      displayMedium: display(typography.displayMedium),
      displaySmall: display(typography.displaySmall),
      headlineLarge: display(typography.headlineLarge)?.copyWith(fontSize: 42),
      headlineMedium: display(typography.headlineMedium)
          ?.copyWith(fontSize: 32),
      headlineSmall: display(typography.headlineSmall),
      titleLarge: display(typography.titleLarge)?.copyWith(fontSize: 26),
      titleMedium: display(typography.titleMedium)?.copyWith(fontSize: 20),
      titleSmall: display(typography.titleSmall)?.copyWith(fontSize: 18),
      bodyLarge: typography.bodyLarge?.copyWith(color: muted, height: 1.6),
      bodyMedium: typography.bodyMedium?.copyWith(height: 1.55),
      bodySmall: typography.bodySmall?.copyWith(color: muted, height: 1.6),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 72,
      titleSpacing: 24,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      labelStyle: const TextStyle(color: muted, fontSize: 13),
      border: const OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: hairline),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: accent, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? muted : ink,
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        textStyle: WidgetStatePropertyAll(
          typography.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        backgroundBuilder: (context, states, child) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: states.contains(WidgetState.disabled)
                ? null
                : bandGradient(glow),
            color: states.contains(WidgetState.disabled) ? raised : null,
            borderRadius: _pill,
          ),
          child: child,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: const StadiumBorder(),
        side: const BorderSide(color: hairlineStrong),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      collapsedTextColor: muted,
      textColor: text,
      iconColor: muted,
      collapsedIconColor: muted,
      shape: Border(),
      collapsedShape: Border(),
      tilePadding: EdgeInsets.zero,
    ),
  );
}

class SonggateMark extends StatelessWidget {
  const SonggateMark({super.key, this.size = 38});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/musiclink.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

class SonggateBrand extends StatelessWidget {
  const SonggateBrand({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SonggateMark(),
      const SizedBox(width: 11),
      Flexible(
        child: Text(appName, style: Theme.of(context).textTheme.titleLarge),
      ),
    ],
  );
}

class PleasanceFooter extends ConsumerWidget {
  const PleasanceFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    margin: const EdgeInsets.only(top: 28),
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: hairline)),
    ),
    child: Row(
      children: [
        Flexible(
          child: Text(
            ref.watch(messagesProvider).madeBy,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 8),
        SvgPicture.asset(
          'assets/pleasance-wordmark.svg',
          width: 76,
          height: 14,
          colorFilter: const ColorFilter.mode(text, BlendMode.srcIn),
          semanticsLabel: 'Pleasance',
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Align(alignment: Alignment.centerRight, child: _BandLine()),
        ),
      ],
    ),
  );
}

class _BandLine extends StatelessWidget {
  const _BandLine();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    height: 9,
    child: LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 3,
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(2)),
                gradient: LinearGradient(
                  colors: [
                    for (final color in glow)
                      Color.lerp(color, Colors.black, 0.55)!,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: constraints.maxWidth * (appBand.from - 1) / 6,
            width: math.max(
              9,
              constraints.maxWidth * (appBand.to - appBand.from) / 6,
            ),
            top: 0,
            height: 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: bandGradient(glow),
                borderRadius: const BorderRadius.all(Radius.circular(5)),
                boxShadow: const [
                  BoxShadow(color: background, spreadRadius: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
