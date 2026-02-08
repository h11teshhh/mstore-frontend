import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class TokenStorage {
  // --- EXISTING CONSTANTS ---
  static const _tokenKey = "access_token";
  static const _nameKey = "user_name";
  static const _roleKey = "user_role";

  // --- NEW: IN-MEMORY CACHE (Makes access instant) ---
  static SharedPreferences? _prefs;
  static String? _cachedToken;
  static String? _cachedName;
  static String? _cachedRole;

  // --- NEW: INITIALIZER ---
  // Call this in your main.dart before runApp() to load data instantly on startup
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _cachedToken = _prefs?.getString(_tokenKey);
    _cachedName = _prefs?.getString(_nameKey);
    _cachedRole = _prefs?.getString(_roleKey);
  }

  // --- EXISTING METHODS (OPTIMIZED) ---

  Future<void> saveLoginData({
    required String token,
    required String name,
    required String role,
  }) async {
    // 1. Save to Disk (Async)
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_tokenKey, token),
      prefs.setString(_nameKey, name),
      prefs.setString(_roleKey, role),
    ]);

    // 2. Update Cache (Instant for next time)
    _cachedToken = token;
    _cachedName = name;
    _cachedRole = role;
  }

  Future<String?> getToken() async {
    // Return cache if available (Instant)
    if (_cachedToken != null) return _cachedToken;

    // Fallback to disk if cache is empty
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  Future<String?> getName() async {
    if (_cachedName != null) return _cachedName;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _cachedName = prefs.getString(_nameKey);
    return _cachedName;
  }

  Future<String?> getRole() async {
    if (_cachedRole != null) return _cachedRole;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _cachedRole = prefs.getString(_roleKey);
    return _cachedRole;
  }

  Future<void> clearAll() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.clear();

    // Clear Cache too
    _cachedToken = null;
    _cachedName = null;
    _cachedRole = null;
  }

  /// Checks JWT expiry (12 AM rule handled by backend exp)
  Future<bool> isTokenValid() async {
    final token = await getToken();
    if (token == null) return false;

    // Safety check for malformed tokens
    try {
      return !JwtDecoder.isExpired(token);
    } catch (e) {
      return false;
    }
  }

  // --- NEW: SYNCHRONOUS GETTERS (Optional) ---
  // Use these if you are 100% sure init() was called in main.dart
  // Example: TokenStorage.syncToken
  static String? get syncToken => _cachedToken;
  static String? get syncRole => _cachedRole;
}
