class Product {
  final int id; // Make sure this matches the server's expected event_product_id
  final String name;
  final String description;
  final double price;
  final int stockQuantity;
  final String? category;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stockQuantity,
    this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int, // Verify this matches the server's field
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: double.parse(json['price']?.toString() ?? '0'),
      stockQuantity: json['quantity'] ?? 0,
      category: json['category'],
    );
  }
}
