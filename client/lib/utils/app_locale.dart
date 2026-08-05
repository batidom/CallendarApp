import 'dart:ui';

import '../l10n/generated/app_localizations.dart';
import '../services/app_settings.dart';

/// The language code the app should actually render in: the user's explicit
/// choice, or — for [AppLanguage.system] — the OS locale if it's one of
/// [AppLocalizations.supportedLocales], falling back to English otherwise.
String resolveLanguageCode(AppLanguage language) {
  final explicit = language.locale;
  if (explicit != null) return explicit.languageCode;

  final systemCode = PlatformDispatcher.instance.locale.languageCode;
  final supported = AppLocalizations.supportedLocales.map((l) => l.languageCode);
  return supported.contains(systemCode) ? systemCode : 'en';
}

/// Resolves localized strings without a [BuildContext] — needed by code that
/// runs outside the widget tree, like [ReminderEngine], which can't call
/// `AppLocalizations.of(context)`.
AppLocalizations resolveL10n(AppLanguage language) {
  return lookupAppLocalizations(Locale(resolveLanguageCode(language)));
}
