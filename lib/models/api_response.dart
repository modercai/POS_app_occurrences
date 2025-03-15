class ApiResponse {
  final bool success;
  final dynamic data;
  final String message;
  final dynamic error;

  ApiResponse({
    required this.success,
    this.data,
    required this.message,
    this.error,
  });
}
