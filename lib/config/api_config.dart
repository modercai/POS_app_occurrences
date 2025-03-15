class ApiConfig {
  static const String baseUrl = 'https://2f01-45-215-255-200.ngrok-free.app/';

  // Vendor-specific endpoints
  //auth endpoints
  static const String vendorMobileLogin = '${baseUrl}accounts/auth/login/';
  static const String refreshToken = '${baseUrl}token/refresh';

  //vendor products endpoint
  static const String inventory = '${baseUrl}api/inventory';

  // Add specific endpoint for product purchase
  // Update the product purchase endpoint
  static const String productPurchase = '${baseUrl}api/nfc-product-purchase/';
  // Make sure there's a trailing slash and the path is exactly as expected by the server
}
