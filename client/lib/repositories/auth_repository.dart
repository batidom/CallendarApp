import '../data/remote/api_client.dart';
import '../data/remote/auth_token_storage.dart';

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final AuthTokenStorage _tokenStorage;

  // No session is started here — the account isn't usable until the emailed
  // code is redeemed via verifyEmail().
  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String username,
    String? surname,
    String? timezone,
  }) async {
    await _apiClient.register(
      email: email,
      password: password,
      name: name,
      username: username,
      surname: surname,
      timezone: timezone,
    );
  }

  Future<void> login({required String email, required String password, bool remember = true}) async {
    final data = await _apiClient.login(email: email, password: password);
    await _startSession(data, remember: remember);
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
    bool remember = true,
  }) async {
    final data = await _apiClient.verifyEmail(email: email, code: code);
    await _startSession(data, remember: remember);
  }

  Future<void> resendVerification(String email) {
    return _apiClient.resendVerification(email);
  }

  Future<void> forgotPassword(String email) {
    return _apiClient.forgotPassword(email);
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
    bool remember = true,
  }) async {
    final data = await _apiClient.resetPassword(email: email, code: code, newPassword: newPassword);
    await _startSession(data, remember: remember);
  }

  Future<Map<String, dynamic>> fetchMyProfile() {
    return _apiClient.fetchMyProfile();
  }

  // Completes a login that was paused by AuthController on
  // TWO_FACTOR_REQUIRED — same "start a session from the response" shape
  // as login()/verifyEmail().
  Future<void> verifyTwoFactor({
    required String twoFactorToken,
    required String code,
    bool remember = true,
  }) async {
    final data = await _apiClient.verifyTwoFactor(twoFactorToken: twoFactorToken, code: code);
    await _startSession(data, remember: remember);
  }

  Future<void> resendTwoFactor(String twoFactorToken) {
    return _apiClient.resendTwoFactor(twoFactorToken);
  }

  Future<Map<String, dynamic>> setupTotp() => _apiClient.setupTotp();

  Future<List<String>> enableTotp(String code) async {
    final data = await _apiClient.enableTotp(code);
    return (data['backupCodes'] as List).cast<String>();
  }

  Future<void> requestEmailTwoFactorCode() async {
    await _apiClient.requestEmailTwoFactorCode();
  }

  Future<List<String>> enableEmailTwoFactor(String code) async {
    final data = await _apiClient.enableEmailTwoFactor(code);
    return (data['backupCodes'] as List).cast<String>();
  }

  Future<void> disableTwoFactor({required String password, required String code}) {
    return _apiClient.disableTwoFactor(password: password, code: code);
  }

  Future<void> updateUsername({required String newUsername, required String password}) {
    return _apiClient.updateUsername(newUsername: newUsername, password: password);
  }

  // Doesn't touch the local session — the caller stays logged in on their
  // current (still-valid) access token throughout. The new address only
  // becomes usable for a fresh login once its code is redeemed via the
  // existing verifyEmail() above, same flow as a brand-new registration.
  Future<void> requestEmailChange({required String newEmail, required String password}) {
    return _apiClient.updateEmail(newEmail: newEmail, password: password);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    return _apiClient.changePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  // Redeems the code for an email change made via requestEmailChange()
  // while already logged in — unlike verifyEmail() above (used right after
  // registration, before any session exists), this doesn't touch the "keep
  // me signed in" choice made at the original login; it just refreshes the
  // current session's tokens in place, same as a silent background refresh
  // would (see ApiClient's 401 retry), so the JWT picks up the new email.
  Future<void> confirmEmailChange({required String email, required String code}) async {
    final data = await _apiClient.verifyEmail(email: email, code: code);
    await _tokenStorage.saveRefreshedTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  Future<void> _startSession(Map<String, dynamic> data, {required bool remember}) {
    return _tokenStorage.startSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: (data['user'] as Map<String, dynamic>)['id'] as String,
      remember: remember,
    );
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    await _apiClient.logout(refreshToken);
    await _tokenStorage.clearToken();
  }

  // The backend already revokes every refresh token as part of deletion, so
  // there's no server-side session left to separately log out of — just
  // drop what's stored locally.
  Future<void> deleteAccount(String password) async {
    await _apiClient.deleteAccount(password);
    await _tokenStorage.clearToken();
  }

  Future<bool> hasValidSession() async {
    final token = await _tokenStorage.readToken();
    return token != null && token.isNotEmpty;
  }
}
