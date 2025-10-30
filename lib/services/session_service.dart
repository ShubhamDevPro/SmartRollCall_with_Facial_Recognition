import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage user sessions and persistence
class SessionService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';
  static const String _keyLastActivity = 'last_activity';

  /// Save session data when user logs in
  Future<void> saveSession({
    required String email,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserRole, role);
    await prefs.setInt(_keyLastActivity, DateTime.now().millisecondsSinceEpoch);
  }

  /// Update last activity timestamp
  Future<void> updateActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastActivity, DateTime.now().millisecondsSinceEpoch);
  }

  /// Check if user session is valid
  Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

    if (!isLoggedIn) return false;

    // Check if Firebase user is still authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await clearSession();
      return false;
    }

    return true;
  }

  /// Get saved user email
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  /// Get saved user role
  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }

  /// Clear session data on logout
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyLastActivity);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }
}
