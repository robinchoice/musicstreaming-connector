import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'messages.dart';

final localeProvider = AsyncNotifierProvider<LocaleController, AppLocale>(
  LocaleController.new,
);

/// Texts in the current language, e.g. `ref.watch(messagesProvider).save`.
final messagesProvider = Provider(
  (ref) => (ref.watch(localeProvider).value ?? AppLocale.de).messages,
);

/// The language chosen in the settings, else the first device language the
/// app speaks, else German. On iOS the choice sits in the app group, so the
/// share extension speaks the same language.
class LocaleController extends AsyncNotifier<AppLocale> {
  static const _channel = MethodChannel('org.musiclink.prototype/preferences');

  @override
  Future<AppLocale> build() async {
    Object? saved;
    try {
      saved = await _channel.invokeMethod<Object?>('getLocale');
    } on PlatformException {
      // No storage, follow the device
    }
    final locale = AppLocale.values.asNameMap()[saved] ?? _deviceLocale();
    ref.read(apiProvider).locale = locale;
    return locale;
  }

  Future<void> toggle() async {
    final next = state.value == AppLocale.en ? AppLocale.de : AppLocale.en;
    ref.read(apiProvider).locale = next;
    state = AsyncData(next);
    try {
      await _channel.invokeMethod('setLocale', next.name);
    } on PlatformException {
      // Kept for this session at least
    }
  }
}

AppLocale _deviceLocale() {
  for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
    final match = AppLocale.values.asNameMap()[locale.languageCode];
    if (match != null) return match;
  }
  return AppLocale.de;
}
