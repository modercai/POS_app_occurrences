class ApiConfig {
  static const String baseUrl = 'https://95ff-197-213-61-131.ngrok-free.app/';

  // Vendor-specific endpoints
  //auth endpoints
  static const String vendorMobileLogin = '${baseUrl}accounts/auth/login/';
  static const String refreshToken = '${baseUrl}token/refresh';

  //vendor products endpoint
  static const String inventory = '${baseUrl}api/inventory';
}
