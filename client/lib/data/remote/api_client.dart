import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'api_exception.dart';
import 'auth_token_storage.dart';

class ApiClient {
  ApiClient(this._dio, this._tokenStorage) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        // A tray instance left running for longer than the access token's
        // lifetime would otherwise start failing every call (sync,
        // assistant chat) with a 401 the moment it expired, with no way
        // back short of a manual re-login. On a 401 from anything other
        // than the auth endpoints themselves, try one silent refresh and
        // replay the original request — completely invisible to the
        // caller if it works.
        onError: (error, handler) async {
          final path = error.requestOptions.path;
          final alreadyRetried = error.requestOptions.extra['retriedAfterRefresh'] == true;
          if (error.response?.statusCode != 401 || path.startsWith('/auth/') || alreadyRetried) {
            handler.next(error);
            return;
          }

          if (!await _refreshAccessToken()) {
            handler.next(error);
            return;
          }

          try {
            final retryOptions = error.requestOptions;
            final token = await _tokenStorage.readToken();
            retryOptions.headers['Authorization'] = 'Bearer $token';
            retryOptions.extra['retriedAfterRefresh'] = true;
            handler.resolve(await _dio.fetch(retryOptions));
          } on DioException catch (retryError) {
            handler.next(retryError);
          }
        },
      ),
    );
  }

  final Dio _dio;
  final AuthTokenStorage _tokenStorage;

  // Multiple requests can 401 around the same moment (e.g. a burst of
  // sync calls right as the token expires) — sharing one in-flight refresh
  // means they all wait on the same result instead of racing separate
  // refresh calls against the single-use rotating refresh token, where all
  // but the first would fail.
  Future<bool>? _refreshInFlight;

  Future<bool> _refreshAccessToken() {
    return _refreshInFlight ??= _doRefreshAccessToken().whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _doRefreshAccessToken() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = response.data as Map<String, dynamic>;
      await _tokenStorage.saveRefreshedTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      // The refresh token itself is invalid/expired (e.g. the tray instance
      // was left running past REFRESH_TOKEN_EXPIRES_IN_DAYS) — clear the
      // now-useless stored session so the next app start shows the login
      // screen instead of optimistically retrying forever.
      await _tokenStorage.clearToken();
      return false;
    }
  }

  Future<void> logout(String? refreshToken) async {
    if (refreshToken == null) return;
    try {
      await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {
      // Best-effort — the local session is cleared by the caller regardless
      // of whether the server-side revocation call actually landed.
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    required String username,
    String? surname,
    String? timezone,
  }) {
    return _request(() => _dio.post('/auth/register', data: {
          'email': email,
          'password': password,
          'name': name,
          'username': username,
          if (surname != null && surname.isNotEmpty) 'surname': surname,
          if (timezone != null) 'timezone': timezone,
        }));
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _request(() => _dio.post('/auth/login', data: {
          'email': email,
          'password': password,
        }));
  }

  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) {
    return _request(() => _dio.post('/auth/verify-email', data: {
          'email': email,
          'code': code,
        }));
  }

  Future<void> resendVerification(String email) {
    return _request(() => _dio.post('/auth/resend-verification', data: {'email': email}));
  }

  Future<void> forgotPassword(String email) {
    return _request(() => _dio.post('/auth/forgot-password', data: {'email': email}));
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _request(() => _dio.post('/auth/reset-password', data: {
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }));
  }

  Future<void> deleteAccount(String password) {
    return _request(() => _dio.delete('/auth/account', data: {'password': password}));
  }

  Future<Map<String, dynamic>> fetchMyProfile() {
    return _request(() => _dio.get('/auth/me'));
  }

  Future<Map<String, dynamic>> updateUsername({
    required String newUsername,
    required String password,
  }) {
    return _request(() => _dio.patch('/auth/username', data: {
          'newUsername': newUsername,
          'password': password,
        }));
  }

  // Returns the (unverified) new email — the caller still needs to redeem a
  // code via ApiClient.verifyEmail before it's usable to log in again.
  Future<Map<String, dynamic>> updateEmail({
    required String newEmail,
    required String password,
  }) {
    return _request(() => _dio.patch('/auth/email', data: {
          'newEmail': newEmail,
          'password': password,
        }));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _request(() => _dio.patch('/auth/password', data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }));
  }

  // Completes a login that was paused by a TWO_FACTOR_REQUIRED response
  // from login() above — code is either a 6-digit code (TOTP or emailed)
  // or a backup code.
  Future<Map<String, dynamic>> verifyTwoFactor({
    required String twoFactorToken,
    required String code,
  }) {
    return _request(() => _dio.post('/auth/2fa/verify', data: {
          'twoFactorToken': twoFactorToken,
          'code': code,
        }));
  }

  // Re-sends the emailed code for a pending email-OTP login; a no-op for a
  // pending TOTP login (nothing server-side to resend).
  Future<Map<String, dynamic>> resendTwoFactor(String twoFactorToken) {
    return _request(() => _dio.post('/auth/2fa/resend', data: {
          'twoFactorToken': twoFactorToken,
        }));
  }

  Future<Map<String, dynamic>> setupTotp() {
    return _request(() => _dio.post('/auth/2fa/totp/setup'));
  }

  Future<Map<String, dynamic>> enableTotp(String code) {
    return _request(() => _dio.post('/auth/2fa/totp/enable', data: {'code': code}));
  }

  // Sends a fresh one-time code to the caller's own email — used both to
  // confirm enabling the email-OTP method and to get a live code before
  // disabling it.
  Future<Map<String, dynamic>> requestEmailTwoFactorCode() {
    return _request(() => _dio.post('/auth/2fa/email/request-code'));
  }

  Future<Map<String, dynamic>> enableEmailTwoFactor(String code) {
    return _request(() => _dio.post('/auth/2fa/email/enable', data: {'code': code}));
  }

  // Method-agnostic: works for whichever method (TOTP/email) is currently
  // active, or a backup code either way.
  Future<void> disableTwoFactor({required String password, required String code}) {
    return _request(() => _dio.post('/auth/2fa/disable', data: {
          'password': password,
          'code': code,
        }));
  }

  Future<List<Map<String, dynamic>>> fetchEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _request(() => _dio.get('/events', queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        }));
    return (response['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> body) {
    return _request(() => _dio.post('/events', data: body));
  }

  Future<Map<String, dynamic>> updateEvent(String id, Map<String, dynamic> body) {
    return _request(() => _dio.put('/events/$id', data: body));
  }

  Future<void> deleteEvent(String id) {
    return _request(() => _dio.delete('/events/$id'));
  }

  Future<void> leaveEvent(String eventId) {
    return _request(() => _dio.post('/events/$eventId/leave'));
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final response = await _request(() => _dio.get('/notifications'));
    return _asList(response);
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final response = await _request(
      () => _dio.get('/friends/search', queryParameters: {'q': query}),
    );
    return _asList(response);
  }

  Future<List<Map<String, dynamic>>> fetchFriends() async {
    final response = await _request(() => _dio.get('/friends'));
    return _asList(response);
  }

  Future<void> removeFriend(String userId) {
    return _request(() => _dio.delete('/friends/$userId'));
  }

  Future<List<Map<String, dynamic>>> fetchIncomingFriendRequests() async {
    final response = await _request(() => _dio.get('/friends/requests/incoming'));
    return _asList(response);
  }

  Future<List<Map<String, dynamic>>> fetchOutgoingFriendRequests() async {
    final response = await _request(() => _dio.get('/friends/requests/outgoing'));
    return _asList(response);
  }

  Future<Map<String, dynamic>> sendFriendRequest(String username) {
    return _request(() => _dio.post('/friends/requests', data: {'username': username}));
  }

  Future<Map<String, dynamic>> acceptFriendRequest(String requestId) {
    return _request(() => _dio.post('/friends/requests/$requestId/accept'));
  }

  Future<void> declineFriendRequest(String requestId) {
    return _request(() => _dio.post('/friends/requests/$requestId/decline'));
  }

  Future<void> cancelFriendRequest(String requestId) {
    return _request(() => _dio.delete('/friends/requests/$requestId'));
  }

  Future<List<Map<String, dynamic>>> fetchGroups() async {
    final response = await _request(() => _dio.get('/groups'));
    return _asList(response);
  }

  /// Groups the current user is a member of (as opposed to [fetchGroups],
  /// which is groups they own) — read-only, since membership doesn't
  /// require the member's acceptance in the first place.
  Future<List<Map<String, dynamic>>> fetchGroupMemberships() async {
    final response = await _request(() => _dio.get('/groups/memberships'));
    return _asList(response);
  }

  Future<Map<String, dynamic>> createGroup(String name) {
    return _request(() => _dio.post('/groups', data: {'name': name}));
  }

  Future<Map<String, dynamic>> renameGroup(String groupId, String name) {
    return _request(() => _dio.put('/groups/$groupId', data: {'name': name}));
  }

  Future<void> deleteGroup(String groupId) {
    return _request(() => _dio.delete('/groups/$groupId'));
  }

  Future<Map<String, dynamic>> addGroupMember(String groupId, String userId) {
    return _request(() => _dio.post('/groups/$groupId/members', data: {'userId': userId}));
  }

  Future<void> removeGroupMember(String groupId, String userId) {
    return _request(() => _dio.delete('/groups/$groupId/members/$userId'));
  }

  Future<List<Map<String, dynamic>>> fetchEventInvites(String eventId) async {
    final response = await _request(() => _dio.get('/events/$eventId/invites'));
    return _asList(response);
  }

  Future<List<Map<String, dynamic>>> inviteToEvent(
    String eventId, {
    List<String> userIds = const [],
    List<String> groupIds = const [],
  }) async {
    final response = await _request(() => _dio.post('/events/$eventId/invites', data: {
          'userIds': userIds,
          'groupIds': groupIds,
        }));
    return _asList(response);
  }

  Future<void> revokeEventInvite(String eventId, String inviteId) {
    return _request(() => _dio.delete('/events/$eventId/invites/$inviteId'));
  }

  Future<List<Map<String, dynamic>>> fetchPendingInvites() async {
    final response = await _request(() => _dio.get('/events/invites/pending'));
    return _asList(response);
  }

  Future<Map<String, dynamic>> respondToInvite(String inviteId, bool accept) {
    return _request(
      () => _dio.post('/events/invites/$inviteId/respond', data: {'accept': accept}),
    );
  }

  Future<List<Map<String, dynamic>>> fetchAttachments(String eventId) async {
    final response = await _request(() => _dio.get('/events/$eventId/attachments'));
    return _asList(response);
  }

  Future<Map<String, dynamic>> uploadAttachment(String eventId, String filePath) {
    // Dio doesn't set a part's Content-Type from the file extension on its
    // own, and the backend's file-type allowlist checks that header — so it
    // has to be worked out and attached here, not left to the default.
    final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
    return _request(() => _dio.post(
          '/events/$eventId/attachments',
          data: FormData.fromMap({
            'file': MultipartFile.fromFileSync(filePath, contentType: MediaType.parse(mimeType)),
          }),
        ));
  }

  Future<void> deleteAttachment(String eventId, String attachmentId) {
    return _request(() => _dio.delete('/events/$eventId/attachments/$attachmentId'));
  }

  /// Streams the attachment's bytes to [savePath] (a local file path the
  /// caller picks, e.g. a temp/cache directory) so it can then be opened
  /// with the system's default app for that file type.
  Future<void> downloadAttachment(String eventId, String attachmentId, String savePath) async {
    try {
      await _dio.download('/events/$eventId/attachments/$attachmentId', savePath);
    } on DioException catch (e) {
      final message = e.message ?? 'Network error';
      throw ApiException(message, statusCode: e.response?.statusCode);
    }
  }

  /// A local LLM doing multi-round tool-calling can easily take much longer
  /// than the app's normal 10s REST timeout, so this one gets its own.
  static const _assistantTimeout = Duration(seconds: 90);

  Future<Map<String, dynamic>> sendAssistantMessage({
    required List<Map<String, String>> messages,
    required String clientNowLocal,
    required int utcOffsetMinutes,
    required String language,
  }) {
    return _request(() => _dio.post(
          '/assistant/chat',
          data: {
            'messages': messages,
            'clientNowLocal': clientNowLocal,
            'utcOffsetMinutes': utcOffsetMinutes,
            'language': language,
          },
          options: Options(sendTimeout: _assistantTimeout, receiveTimeout: _assistantTimeout),
        ));
  }

  /// Uploads a recorded voice command clip to the local whisper.cpp server
  /// (via the backend) and returns the transcribed text — the caller fills
  /// the chat input box with it rather than auto-sending, so the user can
  /// review/edit before it goes to the LLM.
  Future<String> transcribeAudio(String filePath, String language) async {
    final response = await _request(() => _dio.post(
          '/assistant/transcribe',
          data: FormData.fromMap({
            'language': language,
            'audio': MultipartFile.fromFileSync(filePath, contentType: MediaType('audio', 'wav')),
          }),
          options: Options(sendTimeout: _assistantTimeout, receiveTimeout: _assistantTimeout),
        ));
    return response['text'] as String? ?? '';
  }

  Future<Map<String, dynamic>> confirmAssistantDelete(String eventId) {
    return _request(() => _dio.post(
          '/assistant/confirm-delete',
          data: {'eventId': eventId},
          options: Options(sendTimeout: _assistantTimeout, receiveTimeout: _assistantTimeout),
        ));
  }

  List<Map<String, dynamic>> _asList(Map<String, dynamic> response) {
    return ((response['data'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  /// Runs [call], unwraps the response body, and rethrows Dio failures as
  /// [ApiException] with the server's error message when available. List
  /// responses (e.g. `GET /events`) are wrapped as `{'data': [...]}` so the
  /// return type stays consistent.
  Future<Map<String, dynamic>> _request(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final response = await call();
      final data = response.data;
      if (data is List) {
        return {'data': data};
      }
      // Some endpoints (e.g. DELETE) return an empty body, which arrives as
      // "" rather than null — anything that isn't a real JSON object has no
      // meaningful fields for callers, so treat it as empty.
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {};
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (e.message ?? 'Network error');
      throw ApiException(
        message,
        statusCode: e.response?.statusCode,
        data: data is Map<String, dynamic> ? data : null,
      );
    }
  }
}
