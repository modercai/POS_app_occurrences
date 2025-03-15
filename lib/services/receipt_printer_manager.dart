import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:image/image.dart' as img;

class ReceiptPrinterManager {
  FlutterBluetoothSerial bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  BluetoothDevice? _selectedPrinter;
  bool _isInitialized = false;

  Future<bool> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      bool permissionsGranted = await _checkPermissions();
      if (!permissionsGranted) {
        throw Exception('Required permissions not granted');
      }

      bool? isEnabled = await bluetooth.isEnabled;
      if (isEnabled != true) {
        await bluetooth.requestEnable();
      }

      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      for (var device in devices) {
        if (device.name?.contains('MP3P') ?? false) {
          _selectedPrinter = device;
          await _connectToPrinter();
          break;
        }
      }

      if (_selectedPrinter == null) {
        throw Exception('MP3P printer not found');
      }

      _isInitialized = true;
    } catch (e) {
      print('Initialization error: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> _connectToPrinter() async {
    try {
      _connection =
          await BluetoothConnection.toAddress(_selectedPrinter!.address);
      print('Connected to printer: ${_selectedPrinter!.name}');
    } catch (e) {
      print('Printer connection error: $e');
      rethrow;
    }
  }

  Future<Uint8List> _processLogo() async {
    try {
      // Load the logo from assets
      final ByteData data = await rootBundle.load('assets/logo1.png');
      final Uint8List imageBytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      // Decode the image
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) throw Exception('Failed to decode image');

      // Resize image to appropriate width for printer (assuming 384px width)
      final img.Image resizedImage = img.copyResize(
        originalImage,
        width: 384,
        height: -1, // Maintain aspect ratio
      );

      // Convert to grayscale
      final img.Image bwImage = img.grayscale(resizedImage);

      // Convert image to bitmap format
      List<int> commands = [];

      // Printer commands for bitmap
      final int widthBytes = (resizedImage.width + 7) ~/ 8;
      final int height = resizedImage.height;

      // Bitmap command
      commands.add(0x1D);
      commands.add(0x76);
      commands.add(0x30);
      commands.add(0x00);
      commands.add(widthBytes & 0xFF);
      commands.add((widthBytes >> 8) & 0xFF);
      commands.add(height & 0xFF);
      commands.add((height >> 8) & 0xFF);

      // Convert image data to bitmap format
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < widthBytes; x++) {
          int byte = 0;
          for (int bit = 0; bit < 8; bit++) {
            final int px = x * 8 + bit;
            if (px < resizedImage.width) {
              final pixel = bwImage.getPixel(px, y);
              if (pixel.r < 128) {
                byte |= (0x80 >> bit);
              }
            }
          }
          commands.add(byte);
        }
      }

      return Uint8List.fromList(commands);
    } catch (e) {
      print('Logo processing error: $e');
      return Uint8List(0);
    }
  }

  Future<void> printReceipt(Map<String, dynamic> receiptData) async {
    try {
      if (!_isInitialized || _connection?.isConnected != true) {
        await initialize();
      }

      List<int> commands = [];

      // Initialize printer
      commands.add(27);
      commands.add(64); // ESC @

      // Center alignment
      commands.add(27);
      commands.add(97);
      commands.add(1); // ESC a 1

      // Process and add logo
      Uint8List logoBytes = await _processLogo();
      commands.addAll(logoBytes);

      // Add spacing after logo
      commands.add(27);
      commands.add(74);
      commands.add(3); // Feed 3 lines

      // Text size: normal
      commands.add(27);
      commands.add(33);
      commands.add(0); // ESC ! 0

      // Add receipt content
      final content = [
        'Date: ${receiptData['date']}\n',
        'Time: ${receiptData['time']}\n',
        'Transaction #: ${receiptData['transaction_id']}\n',
        '--------------------------------\n',
        '\n',
        'PURCHASE DETAILS\n',
        '--------------------------------\n',
        'Item: ${receiptData['product_name']}\n',
        'Quantity: ${receiptData['quantity']}\n',
        'Price: ZMW ${receiptData['total_amount']}\n',
        '--------------------------------\n',
        '\n',
        'PAYMENT INFORMATION\n',
        '--------------------------------\n',
        'Total Amount: ZMW ${receiptData['total_amount']}\n',
        'Card Balance: ZMW ${receiptData['buyer_balance']}\n',
        '--------------------------------\n',
        '\n',
        'Thank you for your purchase!\n',
        '\n',
        'For support:\n',
        'Tel: +260 XXX XXX XXX\n',
        'Email: support@occurences.com\n',
        '--------------------------------\n',
        '\n\n\n\n\n' // Extra line feeds for better visibility
      ];

      // Add content to commands
      for (var line in content) {
        commands.addAll(utf8.encode(line));
      }

      // Cut paper
      commands.add(29);
      commands.add(86);
      commands.add(1); // GS V 1

      // Send to printer - Updated output handling
      _connection!.output.add(Uint8List.fromList(commands));

      // Wait for data to be sent
      await Future.delayed(const Duration(milliseconds: 500));

      // Instead of flush(), ensure all data is sent
      await _connection!.finish();
    } catch (e) {
      print('Printing error: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      if (_connection?.isConnected == true) {
        await _connection!.close();
      }
      _isInitialized = false;
      _selectedPrinter = null;
    } catch (e) {
      print('Disconnect error: $e');
    }
  }

  void dispose() {
    disconnect();
  }
}
