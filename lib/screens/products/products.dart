import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/cart_provider.dart';
import '../cart/cart.dart';

class Product {
  final String name;
  final String description;
  final double price;
  final int stockQuantity;
  final String category; // Added category field

  Product({
    required this.name,
    required this.description,
    required this.price,
    required this.stockQuantity,
    required this.category,
  });
}

class ProductsPage extends StatefulWidget {
  @override
  _ProductsPageState createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  // Updated sample product data with food and merchandise
  final List<Product> products = [
    Product(
      name: "Burger Combo",
      description: "Beef burger",
      price: 12.99,
      stockQuantity: 50,

      category: "Food",
    ),
    Product(
      name: "Pizza Slice",
      description: "Large pepperoni",
      price: 4.99,
      stockQuantity: 100,
      category: "Food",
    ),
    Product(
      name: "Coca Cola",
      description: "500ml soft drink",
      price: 2.99,
      stockQuantity: 200,
      category: "Drinks",
    ),
    Product(
      name: "Beer",
      description: "Draft beer 500ml",
      price: 5.99,
      stockQuantity: 150,
      category: "Drinks",
    ),
    Product(
      name: "Event T-Shirt",
      description: "Cotton blend, available",
      price: 24.99,
      stockQuantity: 75,
      category: "Merchandise",
    ),
    Product(
      name: "Popcorn",
      description: "Fresh buttered popcorn",
      price: 3.99,
      stockQuantity: 100,
      category: "Snacks",
    ),
    Product(
      name: "Nachos",
      description: "With cheese sauce",
      price: 6.99,
      stockQuantity: 80,
      category: "Snacks",
    ),
    Product(
      name: "Water Bottle",
      description: "500ml mineral water",
      price: 1.99,
      stockQuantity: 300,
      category: "Drinks",
    ),
  ];

  String searchQuery = '';
  String selectedCategory = 'All';

  List<String> get categories => ['All', ...{...products.map((p) => p.category)}];

  List<Product> get filteredProducts => products.where((product) {
    final matchesSearch = product.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
        product.description.toLowerCase().contains(searchQuery.toLowerCase());
    final matchesCategory = selectedCategory == 'All' || product.category == selectedCategory;
    return matchesSearch && matchesCategory;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF312E81),
              Color(0xFF581C87),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button and search
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // In your ProductsPage, add this to the header Row
                    IconButton(
                      icon: Stack(
                        children: [
                          Icon(Icons.shopping_cart, color: Colors.white),
                          Consumer<CartProvider>(
                            builder: (context, cart, child) {
                              if (cart.itemCount == 0) return SizedBox();
                              return Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '${cart.itemCount}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CartPage()),
                        );
                      },
                    ),

                    Text(
                      'Products',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: TextField(
                            style: TextStyle(color: Colors.white),
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search products...',
                              hintStyle: TextStyle(color: Colors.white70),
                              prefixIcon: Icon(Icons.search, color: Colors.white70),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Category Filter
              Container(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: selectedCategory == category,
                        label: Text(category),
                        onSelected: (selected) {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                        backgroundColor: Colors.white.withOpacity(0.1),
                        selectedColor: Colors.blue,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Products Grid
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return ProductCard(product: product);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: Icon(Icons.add),
        onPressed: () {
          // Add new product functionality
        },
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({
    Key? key,
    required this.product,
  }) : super(key: key);

  IconData getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'drinks':
        return Icons.local_drink;
      case 'merchandise':
        return Icons.shopping_bag;
      case 'snacks':
        return Icons.fastfood;
      default:
        return Icons.inventory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        // In your ProductCard class, update the onTap method:
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              decoration: BoxDecoration(
                color: Color(0xFF312E81),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    product.description,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.read<CartProvider>().addItem(product);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product.name} added to cart'),
                              duration: Duration(seconds: 2),
                              action: SnackBarAction(
                                label: 'VIEW CART',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CartPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.add_shopping_cart),
                        label: Text('Add to Cart'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image Placeholder
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      getIconForCategory(product.category),
                      size: 48,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              // Product Details
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      product.description,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ZMW ${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Stock: ${product.stockQuantity}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}