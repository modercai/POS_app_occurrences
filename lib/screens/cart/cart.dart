// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, sort_child_properties_last

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../services/cart_provider.dart';
import '../scan_verify/scan_verify.dart'; // For POSPrinterManager

class CartPage extends StatefulWidget {
  @override
  State<CartPage> createState() => _CartPageState();
}

class Product {
  final int id; // Add this field
  final String name;
  final double price;
  // Other existing fields...

  Product({
    required this.id, // Update constructor
    required this.name,
    required this.price,
    // Other parameters...
  });
}

class _CartPageState extends State<CartPage> {
  final POSPrinterManager _printerManager = POSPrinterManager();
  bool _isPrinterReady = false;

  @override
  void initState() {
    super.initState();
    _initializePrinter();
  }

  Future<void> _initializePrinter() async {
    try {
      await _printerManager.initialize();
      setState(() => _isPrinterReady = true);
    } catch (e) {
      print('Printer initialization error: $e');
      setState(() => _isPrinterReady = false);
    }
  }

  Future<void> _showNFCPromptDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Tap NFC Card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.nfc,
                size: 50,
                color: Colors.blue,
              ),
              SizedBox(height: 16),
              Text('Please tap your NFC card to proceed with checkout'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showPrintDialog(
      BuildContext context, Map<String, dynamic> purchaseDetails) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Print Receipt'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Would you like to print a receipt?'),
                SizedBox(height: 10),
                if (!_isPrinterReady)
                  Text(
                    'Warning: Printer not ready',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('No'),
              ),
              TextButton(
                onPressed:
                    _isPrinterReady ? () => Navigator.pop(context, true) : null,
                child: Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handlePrinting(Map<String, dynamic> purchaseDetails) async {
    try {
      if (!_isPrinterReady) {
        await _initializePrinter();
      }

      await _printerManager.printTicket({
        'event_name': 'Purchase Receipt',
        'ticket_type': 'Transaction',
        'quantity': purchaseDetails['quantity'].toString(),
        'purchase_date': DateTime.now().toString(),
        // Add more details as needed
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt printed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print receipt: $e')),
      );
    }
  }

  Future<void> proceedToCheckout(BuildContext context) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (cartProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your cart is empty')),
      );
      return;
    }

    // Show NFC prompt dialog
    await _showNFCPromptDialog(context);

    try {
      // Start NFC scanning
      String? nfcId = await _scanNFCTag(context);

      // Dismiss the NFC prompt dialog
      Navigator.pop(context);

      if (nfcId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('NFC tag scanning failed')),
        );
        return;
      }

      // For each item in the cart, make an API call
      for (var cartItem in cartProvider.items.values) {
        final response = await http.post(
          Uri.parse(
              'https://95ff-197-213-61-131.ngrok-free.app/api/nfc-product-purchase/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
                'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzM5NzA5MTgzLCJpYXQiOjE3Mzk2MjI3ODMsImp0aSI6ImRkMGYwMzczZjU0MjRkNWY4ODhiYmRkYTM5YmE1NDIxIiwidXNlcl9pZCI6MX0.1Fafhyg4IOY89S9xVgQ5w7rlDbuFqocWn6pPJ_8LQdo',
          },
          body: jsonEncode({
            'nfc_id': nfcId,
            'event_product_id': cartItem.product.id, // Use product ID
            'quantity': cartItem.quantity,
          }),
        );

        if (response.statusCode == 201) {
          final responseData = jsonDecode(response.body);

          // After successful purchase, show print dialog
          final purchaseDetails = {
            'quantity': cartItem.quantity,
            'product_name': cartItem.product.name,
            'price': cartItem.product.price,
            'total': cartItem.quantity * cartItem.product.price,
            'buyer_balance': responseData['buyer_balance'],
          };

          bool shouldPrint = await _showPrintDialog(context, purchaseDetails);
          if (shouldPrint) {
            await _handlePrinting(purchaseDetails);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Purchase successful! Remaining balance: ZMW ${responseData['buyer_balance']}',
              ),
            ),
          );
        } else {
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'Purchase failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Dismiss the NFC prompt dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _scanNFCTag(BuildContext context) async {
    Completer<String?> completer = Completer();

    try {
      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        try {
          final nfca = tag.data['nfca'] ?? {};
          final identifier = nfca['identifier'] as List<int>?;
          if (identifier != null) {
            String nfcId = identifier
                .map((e) => e.toRadixString(16).padLeft(2, '0'))
                .join();
            await NfcManager.instance.stopSession();
            completer.complete(nfcId);
          }
        } catch (e) {
          await NfcManager.instance.stopSession();
          completer.completeError(e);
        }
      });
    } catch (e) {
      completer.completeError(e);
    }

    return completer.future;
  }

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
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Shopping Cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Cart Items List
              Expanded(
                child: Consumer<CartProvider>(
                  builder: (context, cart, child) {
                    if (cart.items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 64, color: Colors.white54),
                            SizedBox(height: 16),
                            Text(
                              'Your cart is empty',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items.values.toList()[index];
                        return CartItemCard(item: item);
                      },
                    );
                  },
                ),
              ),

              // Checkout Section
              Consumer<CartProvider>(
                builder: (context, cart, child) {
                  if (cart.items.isEmpty) return SizedBox();

                  return Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'ZMW ${cart.totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => proceedToCheckout(context),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Proceed to Checkout',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _printerManager.dispose();
    super.dispose();
  }
}

class CartItemCard extends StatelessWidget {
  final CartItem item;

  const CartItemCard({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Product Image/Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.fastfood,
                color: Colors.white70,
                size: 30,
              ),
            ),
            SizedBox(width: 12),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ZMW ${item.product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Quantity Controls
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: Colors.white),
                  onPressed: () {
                    context
                        .read<CartProvider>()
                        .decreaseQuantity(item.product.name);
                  },
                ),
                Text(
                  '${item.quantity}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: Colors.white),
                  onPressed: () {
                    context.read<CartProvider>().addItem(item.product);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
