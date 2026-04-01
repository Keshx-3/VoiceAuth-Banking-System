// lib/services/user_preferences_service.dart
import 'package:shared_preferences/shared_preferences.dart';

// ⚠️ DEPRECATED: This service is no longer used for authentication.
// All authentication is now handled by BankingApiService (lib/api_service/api_service.dart).
// This file is kept only for reference and may be removed in the future.

class UserPreferencesService {
  // Key for storing current logged-in user ID (phone number)
  static const String _keyCurrentUserId = 'current_user_id';

  // Helper method to get user-specific key
  static String _getUserKey(String userId, String suffix) {
    return 'user_${userId}_$suffix';
  }

  // Get current logged-in user ID
  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrentUserId);
  }

  // Set current logged-in user ID
  static Future<void> setCurrentUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUserId, userId);
  }

  // Clear current user ID
  static Future<void> clearCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUserId);
  }

  // Save user data during signup
  static Future<bool> saveUserData({
    required String name,
    required String phone,
    required String pin,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save user-specific data with phone as user ID
      await prefs.setString(_getUserKey(phone, 'name'), name);
      await prefs.setString(_getUserKey(phone, 'phone'), phone);
      await prefs.setString(_getUserKey(phone, 'pin'), pin);
      await prefs.setBool(_getUserKey(phone, 'is_logged_in'), true);
      
      // Set as current user
      await setCurrentUserId(phone);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Validate login credentials
  static Future<bool> validateCredentials({
    required String phone,
    required String pin,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user exists
      final savedPhone = prefs.getString(_getUserKey(phone, 'phone'));
      final savedPin = prefs.getString(_getUserKey(phone, 'pin'));

      if (savedPhone == phone && savedPin == pin) {
        // Set as current logged-in user
        await setCurrentUserId(phone);
        await prefs.setBool(_getUserKey(phone, 'is_logged_in'), true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get user name for current user
  static Future<String?> getUserName() async {
    final userId = await getCurrentUserId();
    if (userId == null) return null;
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_getUserKey(userId, 'name'));
  }

  // Get user phone for current user
  static Future<String?> getUserPhone() async {
    final userId = await getCurrentUserId();
    if (userId == null) return null;
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_getUserKey(userId, 'phone'));
  }

  // Update profile for current user (name only, phone is the ID)
  static Future<bool> updateProfile({
    required String name,
    required String phone,
  }) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return false;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_getUserKey(userId, 'name'), name);
      // Note: We don't update phone as it's the user ID
      return true;
    } catch (e) {
      return false;
    }
  }

  // Check if current user is logged in
  static Future<bool> isLoggedIn() async {
    final userId = await getCurrentUserId();
    if (userId == null) return false;
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_getUserKey(userId, 'is_logged_in')) ?? false;
  }

  // Check if any user exists with given phone (for signup validation)
  static Future<bool> userExists() async {
    final userId = await getCurrentUserId();
    if (userId == null) return false;
    
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_getUserKey(userId, 'phone'));
    return phone != null;
  }

  // Check if a specific user exists by phone
  static Future<bool> userExistsByPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString(_getUserKey(phone, 'phone'));
    return savedPhone != null;
  }

  // Logout current user
  static Future<void> logout() async {
    final userId = await getCurrentUserId();
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_getUserKey(userId, 'is_logged_in'), false);
    }
    // Clear current user ID
    await clearCurrentUserId();
  }

  // Clear all data for current user (for testing)
  static Future<void> clearCurrentUserData() async {
    final userId = await getCurrentUserId();
    if (userId == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getUserKey(userId, 'name'));
    await prefs.remove(_getUserKey(userId, 'phone'));
    await prefs.remove(_getUserKey(userId, 'pin'));
    await prefs.remove(_getUserKey(userId, 'is_logged_in'));
  }

  // Clear all user data (optional, for testing)
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
