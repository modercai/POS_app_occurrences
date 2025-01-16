import 'package:flutter/foundation.dart';
import '../screens/products/products.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  double get total => product.price * quantity;
}

class CartProvider extends ChangeNotifier {
  Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => _items;

  int get itemCount => _items.length;

  double get totalAmount {
    return _items.values.fold(0.0, (sum, item) => sum + item.total);
  }

  void addItem(Product product) {
    if (_items.containsKey(product.name)) {
      // Increase quantity if item exists
      _items.update(
        product.name,
            (existingItem) => CartItem(
          product: existingItem.product,
          quantity: existingItem.quantity + 1,
        ),
      );
    } else {
      // Add new item
      _items.putIfAbsent(
        product.name,
            () => CartItem(product: product),
      );
    }
    notifyListeners();
  }

  void removeItem(String productName) {
    _items.remove(productName);
    notifyListeners();
  }

  void decreaseQuantity(String productName) {
    if (!_items.containsKey(productName)) return;

    if (_items[productName]!.quantity > 1) {
      _items.update(
        productName,
            (existingItem) => CartItem(
          product: existingItem.product,
          quantity: existingItem.quantity - 1,
        ),
      );
    } else {
      _items.remove(productName);
    }
    notifyListeners();
  }

  void clear() {
    _items = {};
    notifyListeners();
  }
}