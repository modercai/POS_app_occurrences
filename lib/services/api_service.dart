import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'auth_services.dart';

class ApiService {
  final AuthService _authService = AuthService();
  final Dio _dio = Dio();

  // Initialize Dio with default settings
  ApiService() {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Add interceptor for handling errors
    _dio.interceptors.add(InterceptorsWrapper(
        onError: (DioError e, handler) async {
          if (e.response?.statusCode == 401) {
            try {
              final isRefreshed = await _authService.refreshAccessToken();
              if (isRefreshed) {
                // Retry the original request
                return handler.resolve(await _retry(e.requestOptions));
              } else {
                await _authService.logout();
                return handler.next(e);
              }
            } catch (refreshError) {
              await _authService.logout();
              return handler.next(e);
            }
          }
          return handler.next(e);
        }
    ));
  }

  // Helper method to retry failed requests
  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final token = await _getValidToken();
    final options = Options(
      method: requestOptions.method,
      headers: {'Authorization': 'Bearer $token'},
    );

    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final token = await _getValidToken();
      final response = await _dio.get(
        endpoint,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return _handleResponse(response);
    } on DioError catch (e) {
      print('API GET error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      print('Unexpected error: $e');
      return null;
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final token = await _getValidToken();
      final response = await _dio.post(
        endpoint,
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return _handleResponse(response);
    } on DioError catch (e) {
      print('API POST error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      print('Unexpected error: $e');
      return null;
    }
  }

  Future<String?> _getValidToken() async {
    // Check and refresh token if needed
    if (!(await _authService.isAuthenticated())) {
      await _authService.refreshAccessToken();
    }

    // Get stored token
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  dynamic _handleResponse(Response response) {
    switch (response.statusCode) {
      case 200:
        return response.data;
      case 401:
      // Handle unauthorized - potentially trigger re-authentication
        _authService.logout();
        return null;
      default:
        print('API Error: ${response.statusCode}');
        return null;
    }
  }

  dynamic _handleDioError(DioError error) {
    if (error.response != null) {
      return _handleResponse(error.response!);
    } else if (error.type == DioErrorType.connectionTimeout) {
      print('Connection timeout');
      return null;
    } else if (error.type == DioErrorType.receiveTimeout) {
      print('Receive timeout');
      return null;
    } else {
      print('Network error: ${error.message}');
      return null;
    }
  }
}