import 'package:dio/dio.dart';
import 'package:occurences_pos/services/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  final Dio _dio = Dio();

  ApiService._internal() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Get token and add to headers for each request
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Handle unauthorized error
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('token');
          // You might want to add navigation to login here
        }
        return handler.next(error);
      },
    ));
  }

  // Login Method
  Future<Map<String, dynamic>> login(String username, String pin) async {
    try {
      final response = await _dio.post(
        ApiConfig.vendorMobileLogin,
        data: {
          'username': username,
          'mobile_pin': pin,
        },
      );

      if (response.statusCode == 200) {
        // Save token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', response.data['access']);

        // Debug print
        print('Login successful. Token saved: ${response.data['access']}');

        return {
          'success': true,
          'data': response.data,
        };
      }

      return {
        'success': false,
        'error': 'Login failed',
      };
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get Products
  Future<Map<String, dynamic>> getProducts() async {
    try {
      final response = await _dio.get(ApiConfig.inventory);
      return {
        'success': true,
        'data': response.data,
      };
    } catch (e) {
      print('Get products error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Add this method
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await _dio.get(endpoint);
      return {
        'success': true,
        'data': response.data,
      };
    } catch (e) {
      print('GET request error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Purchase Product
  Future<Map<String, dynamic>> purchaseProduct({
    required String nfcId,
    required int productId,
    required int quantity,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.productPurchase,
        data: {
          'nfc_id': nfcId,
          'event_product_id': productId,
          'quantity': quantity,
        },
      );

      return {
        'success': true,
        'data': response.data,
      };
    } catch (e) {
      print('Purchase error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> checkBalance(String nfcId) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}accounts/users/balance/',
        queryParameters: {'nfc_id': nfcId},
      );

      // Convert balance to double
      final balance =
          double.tryParse(response.data['balance'].toString()) ?? 0.0;

      return {
        'success': true,
        'data': {
          'balance': balance,
        },
      };
    } catch (e) {
      print('Balance check error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> processCartCheckout(
    String nfcId,
    List<CartItem> items,
  ) async {
    try {
      // Add debug print to verify the data
      print('Checking balance for NFC ID: $nfcId');

      final balanceCheck = await checkBalance(nfcId);
      if (!balanceCheck['success']) {
        return balanceCheck;
      }

      final double balance = balanceCheck['data']['balance'];
      final double totalCost = items.fold(
        0.0,
        (sum, item) => sum + (item.product.price * item.quantity),
      );

      if (balance < totalCost) {
        return {
          'success': false,
          'error': 'Insufficient balance',
          'details': {
            'balance': balance,
            'required': totalCost,
          }
        };
      }

      List<Map<String, dynamic>> purchaseResults = [];
      double remainingBalance = balance;

      for (var cartItem in items) {
        // Debug print the request payload
        final requestData = {
          'nfc_id': nfcId,
          'event_product_id': cartItem.product.id,
          'quantity': cartItem.quantity,
        };
        print('Sending purchase request: $requestData');

        try {
          final response = await _dio.post(
            ApiConfig.productPurchase,
            data: requestData,
            options: Options(
              headers: {
                'Content-Type': 'application/json',
              },
              validateStatus: (status) =>
                  status! < 500, // Accept 400 responses to read error message
            ),
          );

          print('Response status: ${response.statusCode}');
          print('Response data: ${response.data}');

          if (response.statusCode == 201 || response.statusCode == 200) {
            // Updated to match the serializer fields
            remainingBalance = double.tryParse(
                    response.data['buyer_balance']?.toString() ?? '') ??
                remainingBalance;

            purchaseResults.add({
              'success': true,
              'data': {
                'product_name':
                    response.data['product_name'] ?? cartItem.product.name,
                'quantity': cartItem.quantity,
                'price': cartItem.product.price,
                'total': response.data['total_amount'] ??
                    (cartItem.quantity * cartItem.product.price),
                'buyer_balance': remainingBalance,
              },
            });
          } else {
            print('Purchase failed with error: ${response.data}');
            return {
              'success': false,
              'error': response.data['error'] ?? 'Purchase failed',
              'details': response.data,
            };
          }
        } catch (e) {
          print('Individual purchase error: $e');
          return {
            'success': false,
            'error': 'Purchase failed: $e',
          };
        }
      }

      return {
        'success': true,
        'data': purchaseResults.map((r) => r['data']).toList(),
        'final_balance': remainingBalance,
      };
    } catch (e) {
      print('Checkout error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Check Token
  Future<bool> hasValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null;
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}
