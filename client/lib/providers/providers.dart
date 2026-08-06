import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../config/app_config.dart';
import '../data/local/app_database.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/auth_token_storage.dart';
import '../repositories/auth_repository.dart';
import '../repositories/events_repository.dart';
import '../services/app_settings.dart';
import '../services/launch_at_login.dart';
import '../services/reminder_engine.dart';
import '../utils/calendar_grid.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
});

final tokenStorageProvider = Provider<AuthTokenStorage>((ref) => AuthTokenStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider), ref.watch(tokenStorageProvider)),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(
    ref.watch(apiClientProvider),
    ref.watch(appDatabaseProvider),
    ref.watch(tokenStorageProvider),
  ),
);

/// Retries queued offline writes at startup, on every network connectivity
/// change, and on a fixed interval as a fallback for when the network is up
/// but the backend itself was unreachable (e.g. restarted). Watch this
/// provider once near the app root so it's instantiated for the app's
/// lifetime.
final connectivitySyncProvider = Provider<void>((ref) {
  final eventsRepository = ref.watch(eventsRepositoryProvider);

  Future<void> syncAll() async {
    await eventsRepository.syncPendingChanges();
  }

  unawaited(syncAll());

  final subscription = Connectivity().onConnectivityChanged.listen((results) {
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    if (isOnline) {
      unawaited(syncAll());
    }
  });

  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    unawaited(syncAll());
  });

  ref.onDispose(subscription.cancel);
  ref.onDispose(timer.cancel);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

/// The user's app-wide preferences (theme, notification style/position/
/// sound). Persisted locally and loaded once at startup.
final settingsControllerProvider = StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(ref.watch(settingsRepositoryProvider));
});

/// Available audio input devices, for the mic picker in Settings — machines
/// with several mics (headset, webcam, etc.) need this since the OS default
/// isn't always the one the user actually speaks into.
final inputDevicesProvider = FutureProvider<List<InputDevice>>((ref) async {
  final recorder = AudioRecorder();
  try {
    return await recorder.listInputDevices();
  } finally {
    await recorder.dispose();
  }
});

/// Recent-notifications history, newest first. Watch this once near the app
/// root (like [connectivitySyncProvider]) so the engine keeps scanning for
/// the app's whole lifetime, not just while some screen happens to watch it.
final reminderEngineProvider = StateNotifierProvider<ReminderEngine, List<FiredReminder>>((ref) {
  return ReminderEngine(
    ref.watch(eventsRepositoryProvider),
    ref.watch(settingsControllerProvider.notifier),
  );
});

/// Keeps the OS "launch at login" registration in sync with the setting —
/// applied once at startup (which also repairs the registered path if the
/// app binary moved since it was last enabled) and again on every change.
/// Desktop-only; mobile has no such OS concept. Watch this once near the app
/// root (like [connectivitySyncProvider]).
final launchAtLoginSyncProvider = Provider<void>((ref) {
  if (Platform.isAndroid || Platform.isIOS) return;

  bool? lastApplied;
  void apply(bool enabled) {
    if (lastApplied == enabled) return;
    lastApplied = enabled;
    unawaited(LaunchAtLoginService.reconcile(enabled));
  }

  apply(ref.read(settingsControllerProvider).launchAtLoginEnabled);
  ref.listen<AppSettings>(settingsControllerProvider, (previous, next) {
    apply(next.launchAtLoginEnabled);
  });
});

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  needsVerification,
  needsTwoFactor,
}

class AuthState {
  const AuthState(
    this.status, {
    this.errorMessage,
    this.pendingVerificationEmail,
    this.pendingTwoFactorToken,
    this.pendingTwoFactorMethod,
    this.pendingTwoFactorEmail,
  });

  final AuthStatus status;
  final String? errorMessage;

  /// Set when [status] is [AuthStatus.needsVerification] — the address the
  /// code screen should submit against (came either from register() or from
  /// login()'s 403 EMAIL_NOT_VERIFIED response).
  final String? pendingVerificationEmail;

  /// Set when [status] is [AuthStatus.needsTwoFactor] — the bridge token
  /// from login()'s 403 TWO_FACTOR_REQUIRED response, submitted along with
  /// the user's code to AuthRepository.verifyTwoFactor().
  final String? pendingTwoFactorToken;

  /// Which second factor this login is waiting on ('totp' or 'email_otp')
  /// — drives whether the code screen shows a "resend" option and what its
  /// subtitle says.
  final String? pendingTwoFactorMethod;

  /// The account's email, for display ("We sent a code to x@y.com") when
  /// [pendingTwoFactorMethod] is 'email_otp'.
  final String? pendingTwoFactorEmail;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState(AuthStatus.unknown)) {
    _checkSession();
  }

  final AuthRepository _repository;

  Future<void> _checkSession() async {
    final hasSession = await _repository.hasValidSession();
    state = AuthState(hasSession ? AuthStatus.authenticated : AuthStatus.unauthenticated);
  }

  Future<void> login(String email, String password, {bool remember = true}) async {
    try {
      await _repository.login(email: email, password: password, remember: remember);
      state = const AuthState(AuthStatus.authenticated);
    } on ApiException catch (e) {
      if (e.statusCode == 403 && e.data?['code'] == 'EMAIL_NOT_VERIFIED') {
        state = AuthState(
          AuthStatus.needsVerification,
          pendingVerificationEmail: (e.data?['email'] as String?) ?? email,
        );
        return;
      }
      if (e.statusCode == 403 && e.data?['code'] == 'TWO_FACTOR_REQUIRED') {
        state = AuthState(
          AuthStatus.needsTwoFactor,
          pendingTwoFactorToken: e.data?['twoFactorToken'] as String?,
          pendingTwoFactorMethod: e.data?['method'] as String?,
          pendingTwoFactorEmail: e.data?['email'] as String?,
        );
        return;
      }
      state = AuthState(AuthStatus.unauthenticated, errorMessage: e.message);
    }
  }

  Future<void> verifyTwoFactor(String code, {bool remember = true}) async {
    final token = state.pendingTwoFactorToken;
    if (token == null) return;
    try {
      await _repository.verifyTwoFactor(twoFactorToken: token, code: code, remember: remember);
      state = const AuthState(AuthStatus.authenticated);
    } on ApiException catch (e) {
      state = AuthState(
        AuthStatus.needsTwoFactor,
        errorMessage: e.message,
        pendingTwoFactorToken: token,
        pendingTwoFactorMethod: state.pendingTwoFactorMethod,
        pendingTwoFactorEmail: state.pendingTwoFactorEmail,
      );
    }
  }

  /// Re-sends the emailed code for a pending email-OTP login; a no-op
  /// (server-side) for a pending TOTP login.
  Future<void> resendTwoFactorCode() async {
    final token = state.pendingTwoFactorToken;
    if (token == null) return;
    await _repository.resendTwoFactor(token);
  }

  /// Back out of the two-factor code-entry screen to plain sign-in.
  void cancelTwoFactor() {
    state = const AuthState(AuthStatus.unauthenticated);
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String username,
    String? surname,
    String? timezone,
  }) async {
    try {
      await _repository.register(
        email: email,
        password: password,
        name: name,
        username: username,
        surname: surname,
        timezone: timezone,
      );
      state = AuthState(AuthStatus.needsVerification, pendingVerificationEmail: email);
    } on ApiException catch (e) {
      state = AuthState(AuthStatus.unauthenticated, errorMessage: e.message);
    }
  }

  Future<void> verifyEmail(String code, {bool remember = true}) async {
    final email = state.pendingVerificationEmail;
    if (email == null) return;
    try {
      await _repository.verifyEmail(email: email, code: code, remember: remember);
      state = const AuthState(AuthStatus.authenticated);
    } on ApiException catch (e) {
      state = AuthState(
        AuthStatus.needsVerification,
        errorMessage: e.message,
        pendingVerificationEmail: email,
      );
    }
  }

  Future<void> resendVerificationCode() async {
    final email = state.pendingVerificationEmail;
    if (email == null) return;
    await _repository.resendVerification(email);
  }

  /// Returns an error message on failure, null on success — this flow is
  /// screen-local (the login screen manages its own step-by-step UI state),
  /// so unlike login()/register() it doesn't drive [AuthState.status].
  Future<String?> requestPasswordReset(String email) async {
    try {
      await _repository.forgotPassword(email);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// On success this DOES drive [AuthState.status] to authenticated, since a
  /// successful reset logs the user straight in.
  Future<String?> resetPassword({
    required String email,
    required String code,
    required String newPassword,
    bool remember = true,
  }) async {
    try {
      await _repository.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
        remember: remember,
      );
      state = const AuthState(AuthStatus.authenticated);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Back out of the code-entry screen to plain sign-in, e.g. if the user
  /// registered with a typo'd address and needs to start over.
  void cancelVerification() {
    state = const AuthState(AuthStatus.unauthenticated);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(AuthStatus.unauthenticated);
  }

  /// Returns an error message on failure (e.g. wrong password), null on
  /// success.
  Future<String?> deleteAccount(String password) async {
    try {
      await _repository.deleteAccount(password);
      state = const AuthState(AuthStatus.unauthenticated);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);

/// The month currently visible in the calendar UI; drives which range
/// gets fetched from the server and watched from the local database. The
/// result includes every task regardless of state — timed events, loose
/// day items, recurring masters, and backlog ideas all come back together
/// and calendar_screen.dart buckets them locally.
final visibleMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// The calendar grid pads the first/last week of a month with a few days
/// from the neighboring month, so the fetched/watched range must match that
/// full grid — not just the exact month — or those padding days silently
/// show no events despite being visible on screen.
/// The current user's friends. Live server data (no offline cache) —
/// screens re-fetch it via `ref.invalidate` after any mutating action.
final friendsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(apiClientProvider).fetchFriends();
});

final incomingFriendRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(apiClientProvider).fetchIncomingFriendRequests();
});

final outgoingFriendRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(apiClientProvider).fetchOutgoingFriendRequests();
});

final groupsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(apiClientProvider).fetchGroups();
});

final groupMembershipsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(apiClientProvider).fetchGroupMemberships();
});

final pendingEventInvitesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(apiClientProvider).fetchPendingInvites();
});

/// Who's invited to a specific event and their role/status. Only resolves
/// for the owner or an accepted invitee (enforced server-side) — see
/// [EventInvitesService.assertCanView] on the backend.
final eventInvitesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, eventId) {
  return ref.watch(apiClientProvider).fetchEventInvites(eventId);
});

final currentUserIdProvider = FutureProvider<String?>((ref) {
  return ref.watch(tokenStorageProvider).readUserId();
});

/// The signed-in user's own profile (email/username/etc.) — unlike
/// [currentUserIdProvider], this isn't cached locally anywhere (see
/// AuthTokenStorage's doc comment), so it's always a live fetch. Used by the
/// Settings screen's account section; invalidated after a successful
/// username/email change so the displayed value matches what was just set.
final myProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(apiClientProvider).fetchMyProfile();
});

final eventAttachmentsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, eventId) {
  return ref.watch(apiClientProvider).fetchAttachments(eventId);
});

/// Server-side notifications (e.g. someone left a shared event) merged into
/// the same bell dropdown as local reminder firings — see
/// calendar_screen.dart's _buildNotificationsButton. No "read" tracking
/// server-side; like reminders, "seen" is purely a local timestamp cutover.
final notificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(apiClientProvider).fetchNotifications();
});

final eventsForVisibleRangeProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  final repository = ref.watch(eventsRepositoryProvider);
  final month = ref.watch(visibleMonthProvider);
  final weekStartDay = ref.watch(settingsControllerProvider).weekStartDay;

  final range = gridRangeForMonth(month, weekStartDay);

  unawaited(
    repository.refreshRange(range.start, range.endExclusive).catchError((Object error) {
      debugPrint('Failed to refresh events from server: $error');
    }),
  );

  return repository.watchRange(range.start, range.endExclusive);
});
