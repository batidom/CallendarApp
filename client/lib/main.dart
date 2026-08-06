import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

import 'l10n/generated/app_localizations.dart';
import 'providers/providers.dart';
import 'screens/calendar_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notification_popup_screen.dart';
import 'services/app_settings.dart';
import 'services/app_window_controller.dart';
import 'utils/app_locale.dart';

final bool _supportsTray = !kIsWebOrMobile;

// Tray/window management only applies to desktop platforms.
bool get kIsWebOrMobile => Platform.isAndroid || Platform.isIOS;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads date/time symbol data (month/weekday names, etc.) for every
  // bundled locale, so DateFormat works correctly once the app switches to
  // Polish, not just English.
  await initializeDateFormatting();

  if (_supportsTray) {
    // Every window spawned by desktop_multi_window (see
    // services/notification_popup.dart) re-runs this same main() in its own
    // engine; a non-empty argument string is how we tell "this is a
    // reminder popup" apart from "this is the main calendar window".
    await windowManager.ensureInitialized();
    final windowController = await WindowController.fromCurrentEngine();
    if (windowController.arguments.isNotEmpty) {
      final payload = jsonDecode(windowController.arguments) as Map<String, dynamic>;
      runApp(NotificationPopupScreen(
        title: payload['title'] as String,
        message: payload['message'] as String,
        corner: NotificationCorner.values.byName(payload['corner'] as String),
        autoCloseAfter: Duration(seconds: payload['durationSeconds'] as int),
      ));
      return;
    }

    await AppWindowController.instance.init();
    try {
      // Registers the app with Windows/Linux so `LocalNotification.show()`
      // (the "system" notification channel in settings) can display native
      // toasts. Best-effort — a failure here shouldn't block the app from
      // starting, it just means that channel silently does nothing.
      await localNotifier.setup(appName: 'Calendar App');
    } catch (error) {
      debugPrint('Failed to set up native notifications: $error');
    }
  }

  runApp(const ProviderScope(child: CalendarApp()));
}

class CalendarApp extends ConsumerWidget {
  const CalendarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    ref.watch(connectivitySyncProvider);
    // Keeps the reminder engine (sound + popup window) alive for the app's
    // whole lifetime, not just while the notifications bell happens to be
    // on screen.
    ref.watch(reminderEngineProvider);
    ref.watch(launchAtLoginSyncProvider);

    // DateFormat calls throughout the app don't pass an explicit locale, so
    // they follow this global default — kept in sync with the chosen
    // in-app language (or the resolved system language) on every rebuild.
    Intl.defaultLocale = resolveLanguageCode(settings.language);

    return MaterialApp(
      title: 'Calendar App',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true, brightness: Brightness.dark),
      themeMode: settings.themeMode,
      locale: settings.language.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.escape): const HideWindowIntent(),
      },
      actions: {
        ...WidgetsApp.defaultActions,
        HideWindowIntent: CallbackAction<HideWindowIntent>(
          onInvoke: (intent) {
            if (_supportsTray) AppWindowController.instance.toggleVisibility();
            return null;
          },
        ),
      },
      home: switch (authState.status) {
        AuthStatus.unknown => const Scaffold(body: Center(child: CircularProgressIndicator())),
        AuthStatus.unauthenticated => const LoginScreen(),
        AuthStatus.needsVerification => const LoginScreen(),
        AuthStatus.needsTwoFactor => const LoginScreen(),
        AuthStatus.authenticated => const CalendarScreen(),
      },
    );
  }
}

class HideWindowIntent extends Intent {
  const HideWindowIntent();
}
