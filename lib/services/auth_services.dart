import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/api_config.dart';

class AuthService {
  // Update token key to match what we're using elsewhere
  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  Future<bool> mobileLogin(String username, String pin) async {
    try {
      final response = await http.post(Uri.parse(ApiConfig.vendorMobileLogin),
          body: {'username': username, 'mobile_pin': pin});

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          await _saveTokens(response.body);
          return true;
        } catch (e) {
          print('Error saving tokens after successful login: $e');
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Mobile login error: $e');
      return false;
    }
  }

  // Token Storage Methods
  Future<void> _saveTokens(String responseBody) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonResponse = json.decode(responseBody);

      // Add debug prints
      print('Saving tokens...');
      print('Access token: ${jsonResponse['access']}');
      print('Refresh token: ${jsonResponse['refresh']}');

      if (jsonResponse['access'] != null && jsonResponse['refresh'] != null) {
        await prefs.setString(
            _tokenKey, jsonResponse['access']); // Updated to use _tokenKey
        await prefs.setString(_refreshTokenKey, jsonResponse['refresh']);

        // Also save user information
        if (jsonResponse['user_type'] != null) {
          await prefs.setString('user_type', jsonResponse['user_type']);
        }
        if (jsonResponse['user_id'] != null) {
          await prefs.setInt('user_id', jsonResponse['user_id']);
        }
        if (jsonResponse['username'] != null) {
          await prefs.setString('username', jsonResponse['username']);
        }
        print('Tokens and user info saved successfully');
      } else {
        throw Exception('Missing tokens in response');
      }
    } catch (e) {
      print('Error saving tokens: $e');
      throw e; // Re-throw to handle in calling method
    }
  }

  // Token Refresh
  Future<bool> refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_refreshTokenKey);

    if (refreshToken == null) return false;

    try {
      final response = await http.post(Uri.parse(ApiConfig.refreshToken),
          body: {'refresh_token': refreshToken});

      if (response.statusCode == 200) {
        await _saveTokens(response.body);
        return true;
      }
      return false;
    } catch (e) {
      print('Token refresh error: $e');
      return false;
    }
  }

  // Get user type from SharedPreferences
  Future<String?> getUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('user_type');
      print(userType);
      return userType;
    } catch (e) {
      print('Error getting user type: $e');
      return null;
    }
  }

  // Check if user is authenticated and get their type
  Future<Map<String, dynamic>> checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final userType = prefs.getString('user_type');

      if (accessToken == null || userType == null) {
        throw Exception('Not authenticated');
      }

      return {
        'isAuthenticated': true,
        'userType': userType,
        'accessToken': accessToken,
      };
    } catch (e) {
      return {
        'isAuthenticated': false,
        'userType': null,
        'accessToken': null,
      };
    }
  }

  Future<bool> isAuthenticatedWithValidToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userType = prefs.getString('user_type');

      if (token != null && userType != null) {
        // Here you could also validate the token if needed
        return true;
      }
      return false;
    } catch (e) {
      print('Error checking authentication: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) != null;
  }
}
