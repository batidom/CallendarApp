import 'package:shared_preferences/shared_preferences.dart';

/// Stores the JWT, refresh token, and current user id in plain local prefs
/// (not encrypted at rest). Fine for local dev; swap for
/// flutter_secure_storage before shipping if the Windows ATL/MSVC toolset
/// issue is resolved on the target build machine.
///
/// [startSession] takes the "Keep me signed in" choice made at login/
/// register time and remembers it (in [_remember]) for the rest of this
/// process — every later [saveRefreshedTokens] call (from a silent token
/// refresh, see ApiClient) reuses it automatically rather than needing it
/// threaded through the refresh call too. When false, nothing is ever
/// written to disk; values only live in memory for this run. That matters
/// on a shared Windows account: prefs live in the Windows user's own
/// %APPDATA%, so without this, whoever signed in first stays signed in for
/// every other person who later opens the app under that same Windows
/// login, with no prompt at all. remember: false means the next full app
/// restart (by anyone) lands back on the login screen instead.
class AuthTokenStorage {
  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';

  String? _memoryToken;
  String? _memoryRefreshToken;
  String? _memoryUserId;
  bool _remember = true;

  Future<String?> readToken() async {
    if (_memoryToken != null) return _memoryToken;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> readRefreshToken() async {
    if (_memoryRefreshToken != null) return _memoryRefreshToken;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<String?> readUserId() async {
    if (_memoryUserId != null) return _memoryUserId;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<void> startSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required bool remember,
  }) async {
    _remember = remember;
    await _persist(accessToken: accessToken, refreshToken: refreshToken, userId: userId);
  }

  /// Called after a silent background token refresh — reuses whatever
  /// [remember] choice was made at [startSession] time.
  Future<void> saveRefreshedTokens({required String accessToken, required String refreshToken}) {
    return _persist(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> _persist({String? accessToken, String? refreshToken, String? userId}) async {
    if (accessToken != null) _memoryToken = accessToken;
    if (refreshToken != null) _memoryRefreshToken = refreshToken;
    if (userId != null) _memoryUserId = userId;
    if (!_remember) return;

    final prefs = await SharedPreferences.getInstance();
    if (accessToken != null) await prefs.setString(_tokenKey, accessToken);
    if (refreshToken != null) await prefs.setString(_refreshTokenKey, refreshToken);
    if (userId != null) await prefs.setString(_userIdKey, userId);
  }

  Future<void> clearToken() async {
    _memoryToken = null;
    _memoryRefreshToken = null;
    _memoryUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
  }
}
