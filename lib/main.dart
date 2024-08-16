import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expire Calculator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: QRViewExample(),
    );
  }
}

class QRViewExample extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  List<Map<String, dynamic>> savedProducts = [];
  bool isScanning = true;

  @override
  void initState() {
    super.initState();
    _loadSavedProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Walmart Expire Calculator'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    result != null ? 'QR Code Scanned' : 'Scan a code',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.all(8),
                        child: ElevatedButton(
                          onPressed: () async {
                            await controller?.toggleFlash();
                            setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Color.fromARGB(255, 0, 0, 0), // Button color
                            // onPrimary: Colors.white, // Text color
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: FutureBuilder(
                            future: controller?.getFlashStatus(),
                            builder: (context, snapshot) {
                              return Text(
                                'Flash',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 26),
                              );
                            },
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.all(8),
                        child: ElevatedButton(
                          onPressed: () async {
                            await controller?.flipCamera();
                            setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                                255, 0, 0, 0), // Button color
                            // onPrimary: Colors.white, // Text color
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: FutureBuilder(
                            future: controller?.getCameraInfo(),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data != null
                                    ? 'Camera facing ${describeEnum(snapshot.data!)}'
                                    : 'Loading...',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 26),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: ListView.builder(
              itemCount: savedProducts.length,
              itemBuilder: (context, index) {
                final product = savedProducts[index];
                return Container(
                  width: MediaQuery.of(context).size.width *
                      0.8, // Set the width to 80%
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    elevation: 5,
                    color: Color(0xFFF5F5F5),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              product['product_name'] ?? 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: Color(0xFF333333),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 5),
                                Text(
                                  'Description: ${product['description'] ?? 'N/A'}',
                                  style: TextStyle(color: Color(0xFF777777)),
                                ),
                                Text(
                                  'Expiration Date: ${product['expiration_date'] ?? 'N/A'}',
                                  style: TextStyle(color: Color(0xFF777777)),
                                ),
                                Text(
                                  'Days Remaining: ${product['days_remaining'] ?? 'N/A'}',
                                  style: TextStyle(
                                    color: product['days_remaining'] != null &&
                                            product['days_remaining'] < 10
                                        ? Colors.red
                                        : Color.fromARGB(255, 0, 117, 90),
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _removeProduct(index),
                            ),
                          ),
                          Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed:
                                    product['autoReminderEnabled'] == true
                                        ? null
                                        : () => _toggleManualReminder(index),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFC5E1A5),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  product['manualReminderEnabled'] == true
                                      ? 'Disable Manual Reminder'
                                      : 'Enable Manual Reminder',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _toggleAutoReminder(index),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFB3E5FC),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  product['autoReminderEnabled'] == true
                                      ? 'Disable Auto Reminder'
                                      : 'Enable Auto Reminder',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (product['manualReminderEnabled'] == true &&
                              product['manualReminderDate'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Text(
                                'Reminder Date: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(product['manualReminderDate']))}',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (product['autoReminderEnabled'] == true &&
                              product['autoReminderDate'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Text(
                                'Auto Reminder Date: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(product['autoReminderDate']))}',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scheduleNotification(
      DateTime reminderDate, Map<String, dynamic> product) async {
    int notificationId = savedProducts.indexOf(product);
    DateTime now = DateTime.now();

    if (reminderDate.isBefore(now) || reminderDate.isAtSameMomentAs(now)) {
      // Show immediate notification
      await NotificationService().showImmediateNotification(
        notificationId,
        'Product Expiration Reminder',
        '${product['product_name']} is expiring soon!',
      );
    } else {
      // Schedule future notification
      await NotificationService().showNotification(
        notificationId,
        'Product Expiration Reminder',
        '${product['product_name']} is expiring soon!',
        reminderDate,
      );
    }
  }

  Widget _buildQrView(BuildContext context) {
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
          borderColor: Colors.red,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: scanArea),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (isScanning && scanData.code != null) {
        setState(() {
          result = scanData;
          isScanning = false;
        });
        controller.pauseCamera();
        _processQRData(scanData.code!);
      }
    });
  }

  void _toggleManualReminder(int index) async {
    if (savedProducts[index]['manualReminderEnabled'] == true) {
      setState(() {
        savedProducts[index]['manualReminderEnabled'] = false;
      });
      await NotificationService().cancelNotification(index);
    } else {
      int? daysBeforeReminder = await _showManualReminderDialog();
      if (daysBeforeReminder != null) {
        DateFormat dateFormat = DateFormat('dd/MM/yyyy');
        DateTime expirationDate =
            dateFormat.parse(savedProducts[index]['expiration_date']);
        DateTime reminderDate =
            expirationDate.subtract(Duration(days: daysBeforeReminder));
        DateTime now = DateTime.now();

        if (reminderDate.isBefore(now)) {
          reminderDate = now;
        }

        await _scheduleNotification(reminderDate, savedProducts[index]);

        setState(() {
          savedProducts[index]['manualReminderEnabled'] = true;
          savedProducts[index]['manualReminderDays'] = daysBeforeReminder;
          savedProducts[index]['manualReminderDate'] =
              reminderDate.toIso8601String();
        });
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await _updateSavedProducts(prefs);
  }

  Future<int?> _showManualReminderDialog() async {
    TextEditingController daysController = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set Manual Reminder'),
          content: TextField(
            controller: daysController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter number of days before expiration',
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(null),
            ),
            TextButton(
              child: Text('Set Reminder'),
              onPressed: () {
                int? days = int.tryParse(daysController.text);
                Navigator.of(context).pop(days);
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleAutoReminder(int index) async {
    setState(() {
      savedProducts[index]['autoReminderEnabled'] =
          !(savedProducts[index]['autoReminderEnabled'] ?? false);

      if (savedProducts[index]['autoReminderEnabled'] == true) {
        savedProducts[index]['manualReminderEnabled'] = false;

        DateFormat dateFormat = DateFormat('dd/MM/yyyy');
        DateTime expirationDate =
            dateFormat.parse(savedProducts[index]['expiration_date']);
        int daysRemaining = expirationDate.difference(DateTime.now()).inDays;

        int daysBeforeReminder = (daysRemaining / 4).round();
        DateTime reminderDate =
            expirationDate.subtract(Duration(days: daysBeforeReminder));
        DateTime now = DateTime.now();

        if (reminderDate.isBefore(now)) {
          reminderDate = now;
        }

        savedProducts[index]['autoReminderDate'] =
            reminderDate.toIso8601String();
        _scheduleNotification(reminderDate, savedProducts[index]);
      } else {
        savedProducts[index]['autoReminderDate'] = null;
        NotificationService().cancelNotification(index);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await _updateSavedProducts(prefs);
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No Permission')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProducts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('savedProducts');
    if (savedData != null && savedData.isNotEmpty) {
      setState(() {
        savedProducts = List<Map<String, dynamic>>.from(jsonDecode(savedData));
      });
    }
  }

  Future<void> _saveProducts(List<Map<String, dynamic>> products) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedProducts.addAll(products);
    });
    await _updateSavedProducts(prefs);
  }

  Future<void> _updateSavedProducts(SharedPreferences prefs) async {
    await prefs.setString('savedProducts', jsonEncode(savedProducts));
  }

  void _removeProduct(int index) async {
    await NotificationService().cancelNotification(index);
    setState(() {
      savedProducts.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    await _updateSavedProducts(prefs);
  }

  void _processQRData(String qrData) async {
    final response = await http.post(
      Uri.parse('http://192.168.255.15:5000/api/qrdata'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'qr_data': qrData,
      }),
    );

    if (response.statusCode == 200) {
      List<dynamic> productsData = jsonDecode(response.body);
      if (productsData.isNotEmpty) {
        _showProductsDialog(productsData.cast<Map<String, dynamic>>());
      } else {
        print('No product data in the response');
        _resetScanner();
      }
    } else {
      print('Failed to process QR data: ${response.statusCode}');
      print('Response body: ${response.body}');
      _resetScanner();
    }
  }

  void _showProductsDialog(List<Map<String, dynamic>> products) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Scanned Products'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: products.map((product) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Product Name: ${product['product_name'] ?? 'N/A'}'),
                    Text('Description: ${product['description'] ?? 'N/A'}'),
                    Text(
                        'Expiration Date: ${product['expiration_date'] ?? 'N/A'}'),
                    Text(
                        'Days Remaining: ${product['days_remaining']?.toString() ?? 'N/A'}'),
                    Divider(),
                  ],
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Save All'),
              onPressed: () {
                _saveProducts(products);
                Navigator.of(context).pop();
                _resetScanner();
              },
            ),
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
                _resetScanner();
              },
            ),
          ],
        );
      },
    );
  }

  void _resetScanner() {
    setState(() {
      result = null;
      isScanning = true;
    });
    controller?.resumeCamera();
  }
}

String describeEnum(Object enumEntry) {
  final String description = enumEntry.toString();
  final int indexOfDot = description.indexOf('.');
  assert(indexOfDot != -1 && indexOfDot < description.length - 1);
  return description.substring(indexOfDot + 1);
}
