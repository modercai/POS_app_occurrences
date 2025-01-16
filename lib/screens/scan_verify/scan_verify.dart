import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:permission_handler/permission_handler.dart';

class POSPrinterManager {
  FlutterBluetoothSerial bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  BluetoothDevice? _selectedPrinter;
  bool _isInitialized = false;
  bool _isScanning = false;

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
      _connection = await BluetoothConnection.toAddress(_selectedPrinter!.address);
      print('Connected to printer: ${_selectedPrinter!.name}');
    } catch (e) {
      print('Printer connection error: $e');
      rethrow;
    }
  }

  Future<void> printTicket(Map<String, dynamic> ticketDetails) async {
    try {
      if (!_isInitialized || _connection?.isConnected != true) {
        await initialize();
      }

      List<int> bytes = [];

      // Initialize printer
      bytes += [27, 64];  // ESC @

      // Center alignment
      bytes += [27, 97, 1];  // ESC a 1

      // Text size: normal
      bytes += [27, 33, 0];  // ESC ! 0

      // Add header
      bytes += utf8.encode('EVENT TICKET\n');
      bytes += utf8.encode('----------------\n');

      // Add ticket details
      bytes += utf8.encode('Event: ${ticketDetails['event_name'] ?? 'N/A'}\n');
      bytes += utf8.encode('Type: ${ticketDetails['ticket_type'] ?? 'N/A'}\n');
      bytes += utf8.encode('Quantity: ${ticketDetails['quantity'] ?? 'N/A'}\n');
      bytes += utf8.encode('Date: ${ticketDetails['purchase_date'] ?? 'N/A'}\n');
      bytes += utf8.encode('----------------\n\n');

      // Feed and cut
      bytes += [27, 74, 3];  // Feed 3 lines
      bytes += [29, 86, 1];  // GS V 1 - Cut paper

      // Send to printer
      _connection!.output.add(Uint8List.fromList(bytes));
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
      setState(() {
        _nfcAvailable = isAvailable;
        _statusMessage = isAvailable ? 'Ready to scan' : 'NFC not available';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Error checking NFC: $e');
    }
  }

  Future<void> _startNFCScanning() async {
    if (!_nfcAvailable) return;
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for NFC tag...';
    });

    try {
      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        String? identifier = await _extractNFCId(tag);
        if (identifier != null) {
          setState(() => _statusMessage = 'Tag read: $identifier');
          await _verifyTicket(identifier);
        }
      });
    } catch (e) {
      setState(() => _statusMessage = 'NFC error: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<String?> _extractNFCId(NfcTag tag) async {
    try {
      final nfca = tag.data['nfca'] ?? {};
      final identifier = nfca['identifier'] as List<int>?;
      if (identifier != null) {
        return identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
      }
    } catch (e) {
      print('NFC extraction error: $e');
    }
    return null;
  }

  Future<void> _verifyTicket(String nfcId) async {
    try {
      final response = await http.post(
        Uri.parse('https://9e4d-45-215-255-59.ngrok-free.app/api/verify-nfc-action/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzM3MDI1ODY0LCJpYXQiOjE3MzY5Mzk0NjQsImp0aSI6ImQxMjYwNjJiMWZlYzRlZjRhZDE0NzJhOTYyYzkwYzEzIiwidXNlcl9pZCI6MX0.hoNkVdVPA0H76bLlOMlq7odgVXr7sFnUiCSeJC74QcA',
        },
        body: jsonEncode({
          'nfc_id': nfcId,
          'action_type': 'TICKET_VERIFY',
          'ticket_id': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _showVerificationResult(true, data['ticket_details']);
      } else {
        final error = jsonDecode(response.body)['error'];
        await _showVerificationResult(false, {'error': error});
      }
    } catch (e) {
      print('API error: $e');
      await _showVerificationResult(false, {'error': 'Connection error'});
    }
  }

  Future<void> _initializePrinter() async {
    try {
      await _printerManager.initialize();
      setState(() {
        _isPrinterReady = true;
        _statusMessage = 'System ready';
      });
    } catch (e) {
      setState(() {
        _isPrinterReady = false;
        _statusMessage = 'Printer error: $e';
      });
    }
  }

// When printing
  Future<void> _printTicket(Map<String, dynamic> ticketDetails) async {
    try {
      setState(() => _statusMessage = 'Printing ticket...');
      await _printerManager.printTicket(ticketDetails);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket printed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print ticket: $e')),
      );
    } finally {
      setState(() => _statusMessage = 'Ready to scan');
    }
  }

  @override
  void dispose() {
    _printerManager.dispose();
    super.dispose();
  }

  Future<void> _showVerificationResult(bool isValid, Map<String, dynamic> details) async {
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
                      style: ElevatedButton.styleFrom(

                      ),
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