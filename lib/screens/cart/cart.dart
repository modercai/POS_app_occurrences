// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, sort_child_properties_last

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../services/cart_provider.dart';
import '../../services/api_service.dart'; // Import the ApiService
import '../../services/receipt_printer_manager.dart';

class CartPage extends StatefulWidget {
  @override
  State<CartPage> createState() => _CartPageState();
}

// Remove the Product class definition since we're now using the shared model

class _CartPageState extends State<CartPage> {
  final ReceiptPrinterManager _printerManager = ReceiptPrinterManager();
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
          title: Row(
            children: [
              Icon(Icons.nfc, color: Colors.blue),
              SizedBox(width: 8),
              Text('Tap NFC Card'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nfc),
              SizedBox(height: 16),
              Text(
                'Please ask the customer to tap their NFC card to proceed with payment',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
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

      final now = DateTime.now();
      final formattedDate = "${now.day}/${now.month}/${now.year}";
      final formattedTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      // Format receipt data
      final receiptData = {
        'date': formattedDate,
        'time': formattedTime,
        'transaction_id': purchaseDetails['id'],
        'product_name': purchaseDetails['product_name'],
        'quantity': purchaseDetails['quantity'],
        'total_amount': purchaseDetails['total_amount'],
        'buyer_balance': purchaseDetails['buyer_balance'],
      };

      // Print receipt using new manager
      await _printerManager.printReceipt(receiptData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt printed successfully')),
      );
    } catch (e) {
      print('Printing error details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print receipt: $e')),
      );
    }
  }

  Future<void> proceedToCheckout(BuildContext context) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final apiService = ApiService();

    if (cartProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your cart is empty')),
      );
      return;
    }

    // Show scanning dialog
    await _showNFCPromptDialog(context);

    try {
      // Start NFC scanning
      String? nfcId = await _scanNFCTag(context);
      if (!mounted) return;

      // Close NFC prompt
      Navigator.pop(context);

      if (nfcId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('NFC tag scanning failed')),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await apiService.processCartCheckout(
        nfcId,
        cartProvider.items.values.toList(),
      );

      // Close loading indicator
      Navigator.pop(context);

      if (result['success']) {
        // Get the purchase data (assuming it's a list of purchases)
        final List<dynamic> purchases = result['data'];
        if (purchases.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No purchase data received')),
          );
          return;
        }

        // Get the last purchase for the receipt
        final lastPurchase = purchases.last;

        // Debug print to verify the data
        print('Last Purchase Data: $lastPurchase');

        final shouldPrint = await _showTransactionSuccessDialog(
          context,
          purchases,
          lastPurchase['buyer_balance'],
        );

        if (shouldPrint) {
          // Create a properly formatted purchase details map
          final printData = {
            'id': lastPurchase['id']?.toString() ?? 'N/A',
            'product_name':
                lastPurchase['product_name']?.toString() ?? 'Unknown Product',
            'quantity': lastPurchase['quantity']?.toString() ?? '0',
            'total_amount':
                (lastPurchase['total_amount'] ?? 0.0).toStringAsFixed(2),
            'buyer_balance':
                (lastPurchase['buyer_balance'] ?? 0.0).toStringAsFixed(2),
            'created_at': lastPurchase['created_at']?.toString() ??
                DateTime.now().toString(),
          };
          await _handlePrinting(printData);
        }

        // Clear cart and navigate back
        cartProvider.clear();
        Navigator.pop(context);
      } else {
        _showErrorDialog(context, result['error'], result['details']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Future<bool> _showTransactionSuccessDialog(
    BuildContext context,
    List<dynamic> purchases,
    dynamic finalBalance,
  ) async {
    // Safely parse the final balance
    double safeBalance = 0.0;
    try {
      safeBalance =
          finalBalance != null ? double.parse(finalBalance.toString()) : 0.0;
    } catch (e) {
      print('Error parsing final balance: $e');
    }

    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Purchase Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction Summary:'),
            SizedBox(height: 8),
            ...purchases.map((purchase) {
              // Safely parse numeric values
              int quantity = 0;
              double totalAmount = 0.0;
              String productName =
                  purchase['product_name']?.toString() ?? 'Unknown Product';

              try {
                quantity = int.parse(purchase['quantity']?.toString() ?? '0');
              } catch (e) {
                print('Error parsing quantity: $e');
              }

              try {
                totalAmount =
                    double.parse(purchase['total_amount']?.toString() ?? '0.0');
              } catch (e) {
                print('Error parsing total amount: $e');
              }

              return Text(
                '${quantity}x $productName - ZMW ${totalAmount.toStringAsFixed(2)}',
              );
            }).toList(),
            Divider(),
            Text(
              'Remaining Balance: ZMW ${safeBalance.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Would you like to print a receipt?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, Print Receipt'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String error, dynamic details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Transaction Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error),
            if (details != null && details['balance'] != null) ...[
              SizedBox(height: 8),
              Text(
                'Available Balance: ZMW ${details['balance']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Required Amount: ZMW ${details['required']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
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
