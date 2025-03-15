import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

class POSPrinterManager {
  FlutterBluetoothSerial bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  BluetoothDevice? _selectedPrinter;
  bool _isInitialized = false;

  Future<bool> _checkPermissions() async {
    try {
      if (!await NfcManager.instance.isAvailable()) {
        throw Exception('Bluetooth is not available on this device');
      }

      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();

      return statuses.values.every((status) => status.isGranted);
    } catch (e) {
      print('Permission check error: $e');
      return false;
    }
  }

  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      bool permissionsGranted = await _checkPermissions();
      if (!permissionsGranted) {
        throw Exception('Required permissions not granted');
      }

      // Enable Bluetooth
      bool? isEnabled = await bluetooth.isEnabled;
      if (isEnabled != true) {
        await bluetooth.requestEnable();
      }

      // Search for MP3P printer
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

  Uint8List _convertToUint8List(List<int> data) {
    return Uint8List.fromList(data);
  }

  Future<Uint8List> _processLogo() async {
    try {
      // Load the logo from assets
      final ByteData data = await rootBundle.load('assets/logo1.png');
      final Uint8List imageBytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Decode the image using the Uint8List
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
              // Get the pixel and extract its luminance
              final pixel = bwImage.getPixel(px, y);
              // In grayscale image, r/g/b values are the same
              final int intensity = pixel.r.toInt();
              // Consider pixel black if below threshold
              if (intensity < 128) {
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

  Future<void> printTicket(Map<String, dynamic> ticketDetails) async {
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

      // Add some spacing after logo
      commands.add(27);
      commands.add(74);
      commands.add(2); // Feed 2 lines

      // Text size: normal
      commands.add(27);
      commands.add(33);
      commands.add(0); // ESC ! 0

      // Add header
      commands.addAll(utf8.encode('EVENT TICKET\n'));
      commands.addAll(utf8.encode('----------------\n'));

      // Add ticket details
      commands.addAll(
          utf8.encode('Event: ${ticketDetails['event_name'] ?? 'N/A'}\n'));
      commands.addAll(
          utf8.encode('Type: ${ticketDetails['ticket_type'] ?? 'N/A'}\n'));
      commands.addAll(
          utf8.encode('Quantity: ${ticketDetails['quantity'] ?? 'N/A'}\n'));
      commands.addAll(utf8.encode(
          'Date: ${ticketDetails['purchase_date'] ?? 'N/A'}\n\n\n\n\n'));
      commands.addAll(utf8.encode('----------------\n\n'));

      // Feed and cut
      commands.add(27);
      commands.add(74);
      commands.add(3); // Feed 3 lines
      commands.add(29);
      commands.add(86);
      commands.add(1); // GS V 1 - Cut paper

      // Convert final commands to Uint8List
      final Uint8List finalBytes = Uint8List.fromList(commands);

      // Send to printer
      _connection!.output.add(finalBytes);
      await _connection!.output.allSent;

      print('Ticket printed successfully');
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

class NFCVerificationPage extends StatefulWidget {
  @override
  _NFCVerificationPageState createState() => _NFCVerificationPageState();
}

class _NFCVerificationPageState extends State<NFCVerificationPage> {
  bool _nfcAvailable = false;
  String _statusMessage = 'Initializing NFC...';
  bool _isScanning = false;
  bool _isPrinterReady = false;

  final POSPrinterManager _printerManager = POSPrinterManager();

  @override
  void initState() {
    super.initState();
    _checkNFCAvailability();
    _initializePrinter();
  }

  Future<void> _checkNFCAvailability() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!mounted) return;
      setState(() {
        _nfcAvailable = isAvailable;
        _statusMessage = isAvailable ? 'Ready to scan' : 'NFC not available';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Error checking NFC: $e');
    }
  }

  Future<void> _startNFCScanning() async {
    if (!_nfcAvailable || !mounted) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for NFC tag...';
    });

    try {
      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        if (!mounted) return;

        String? identifier = await _extractNFCId(tag);
        if (identifier != null) {
          if (!mounted) return;

          setState(() => _statusMessage = 'Tag read: $identifier');
          await _verifyTicket(identifier);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'NFC error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isScanning = false);
    }
  }

  Future<String?> _extractNFCId(NfcTag tag) async {
    try {
      final nfca = tag.data['nfca'] ?? {};
      final identifier = nfca['identifier'] as List<int>?;
      if (identifier != null) {
        return identifier
            .map((e) => e.toRadixString(16).padLeft(2, '0'))
            .join();
      }
    } catch (e) {
      print('NFC extraction error: $e');
    }
    return null;
  }

  Future<void> _verifyTicket(String nfcId) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://2f01-45-215-255-200.ngrok-free.app/api/verify-nfc-action/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzQwMDk5MDM4LCJpYXQiOjE3NDAwMTI2MzgsImp0aSI6IjE2NDMxMDQzOTg4YjQ0YjViOGYyMDRjNTE1ZTVjZjAyIiwidXNlcl9pZCI6Mn0.vL6Jhb8tzZyb0Y102LELN2pSatkxIFcXEGkesg-KeTs',
        },
        body: jsonEncode({
          'nfc_id': nfcId,
          'action_type': 'TICKET_VERIFY',
          'ticket_id': 1,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _showVerificationResult(true, data['ticket_details']);
      } else {
        final error = jsonDecode(response.body)['error'];
        await _showVerificationResult(false, {'error': error});
      }
    } catch (e) {
      if (!mounted) return;
      print('API error: $e');
      await _showVerificationResult(false, {'error': 'Connection error'});
    }
  }

  Future<void> _initializePrinter() async {
    try {
      await _printerManager.initialize();
      if (!mounted) return;
      setState(() {
        _isPrinterReady = true;
        _statusMessage = 'System ready';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPrinterReady = false;
        _statusMessage = 'Printer error: $e';
      });
    }
  }

// When printing
  Future<void> _printTicket(Map<String, dynamic> ticketDetails) async {
    if (!mounted) return;

    try {
      setState(() => _statusMessage = 'Printing ticket...');
      await _printerManager.printTicket(ticketDetails);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket printed successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print ticket: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _statusMessage = 'Ready to scan');
    }
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession(); // Stop NFC session
    _printerManager.dispose();
    super.dispose();
  }

  Future<void> _showVerificationResult(
      bool isValid, Map<String, dynamic> details) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isValid ? 'Valid Ticket' : 'Invalid Ticket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event: ${details['event_name'] ?? 'N/A'}'),
            Text('Type: ${details['ticket_type'] ?? 'N/A'}'),
            Text('Quantity: ${details['quantity'] ?? 'N/A'}'),
            Text('Date: ${details['purchase_date'] ?? 'N/A'}'),
          ],
        ),
        actions: [
          if (isValid)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _printTicket(details);
              },
              child: Text('Print Ticket'),
            ),
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
      appBar: AppBar(
        title: const Text('Ticket Verification'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple, Colors.deepPurple.shade200],
          ),
        ),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isScanning ? Icons.nfc : Icons.touch_app,
                    size: 80,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _nfcAvailable ? _startNFCScanning : null,
                      style: ElevatedButton.styleFrom(),
                      child: Text(
                        _isScanning ? 'Scanning...' : 'Scan Ticket',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isPrinterReady ? Icons.check_circle : Icons.error,
                        color: _isPrinterReady ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPrinterReady ? 'Printer Ready' : 'Printer Not Ready',
                        style: TextStyle(
                          color: _isPrinterReady ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
