import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../models/product_model.dart';

class BillingController extends ChangeNotifier {
  final List<Product> _cartItems = [];
  List<Product> get cartItems => _cartItems;

  final AudioPlayer _audioPlayer = AudioPlayer();
  SharedPreferences? _prefs;

  final BlueThermalPrinter _bluetoothManager = BlueThermalPrinter.instance;
  List<BluetoothDevice> _discoveredDevices = [];
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  bool _isPrinterConnected = false;
  bool get isPrinterConnected => _isPrinterConnected;

  Map<String, Map<String, dynamic>> _localDatabase = {};
  Map<String, Map<String, dynamic>> get localDatabaseRegistry => _localDatabase;
  
  Map<String, List<Map<String, dynamic>>> _salesHistory = {};
  Map<String, List<Map<String, dynamic>>> get salesHistory => _salesHistory;

  double _totalSalesToday = 0.0;
  double get totalSalesToday => _totalSalesToday;

  int _checkoutCountToday = 0;
  int get checkoutCountToday => _checkoutCountToday;

  BillingController() {
    _initDatabase();
    _checkPrinterStatus();
    checkForUpdates();
  }

  Future<void> _initDatabase() async {
    _prefs = await SharedPreferences.getInstance();
    
    String? storedData = _prefs?.getString('local_products_db');
    if (storedData != null) {
      _localDatabase = Map<String, Map<String, dynamic>>.from(jsonDecode(storedData));
    } else {
      _localDatabase = {
        '8901058002315': {'name': 'Bourbon Biscuit 100g', 'price': 10.0},
        '8901138450135': {'name': 'Dabur Honey', 'price': 75.0},
        '8901262010049': {'name': 'Haldirams Bhujia', 'price': 20.0},
      };
      await _saveDatabaseToDisk();
    }

    String? storedSales = _prefs?.getString('sales_history_db');
    if (storedSales != null) {
      final decodedSales = jsonDecode(storedSales) as Map<String, dynamic>;
      _salesHistory = decodedSales.map((key, value) => MapEntry(key, List<Map<String, dynamic>>.from(value)));
      _calculateTodayMetrics();
    }
    
    notifyListeners();
  }

  void _checkPrinterStatus() {
    _bluetoothManager.isConnected.then((status) {
      _isPrinterConnected = status ?? false;
      notifyListeners();
    });

    _bluetoothManager.onStateChanged().listen((state) {
      if (state == BlueThermalPrinter.DISCONNECTED) {
        _isPrinterConnected = false;
        _connectedDevice = null;
        notifyListeners();
      }
    });
  }

  Future<void> scanForPrinters() async {
    try {
      _discoveredDevices = await _bluetoothManager.getBondedDevices();
      notifyListeners();
    } catch (e) {
      debugPrint("Bluetooth tracking scan exception: $e");
    }
  }

  Future<void> connectToPrinter(BluetoothDevice device) async {
    try {
      await _bluetoothManager.connect(device);
      _connectedDevice = device;
      _isPrinterConnected = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Printer socket connection fault: $e");
      _isPrinterConnected = false;
    }
  }

  Future<void> disconnectPrinter() async {
    await _bluetoothManager.disconnect();
    _isPrinterConnected = false;
    _connectedDevice = null;
    notifyListeners();
  }

  double get totalCartAmount {
    return _cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  Future<void> playTingSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/ting.mp3'));
    } catch (e) {
      debugPrint("Audio engine playback error: $e");
    }
  }

  void showScanToast(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void incrementQuantity(String barcode) {
    int index = _cartItems.indexWhere((item) => item.barcode == barcode);
    if (index != -1) {
      _cartItems[index].quantity++;
      notifyListeners();
    }
  }

  void decrementQuantity(String barcode, BuildContext context) {
    int index = _cartItems.indexWhere((item) => item.barcode == barcode);
    if (index != -1) {
      if (_cartItems[index].quantity > 1) {
        _cartItems[index].quantity--;
      } else {
        removeCartItem(barcode, context, _cartItems[index].name);
      }
      notifyListeners();
    }
  }

  // 🚀 FIXED: Duplicate Scan Popup Interceptor
  Future<bool> processScannedBarcode(String barcode, BuildContext context) async {
    int existingIndex = _cartItems.indexWhere((item) => item.barcode == barcode);
    if (existingIndex != -1) {
      // Pause scanner and await user confirmation
      bool? confirm = await _showDuplicateScanDialog(context, _cartItems[existingIndex].name);
      if (confirm == true) {
        _cartItems[existingIndex].quantity++;
        showScanToast(context, "Added another ${_cartItems[existingIndex].name}! (${_cartItems[existingIndex].quantity})");
        notifyListeners();
        return true; // Successfully added
      }
      return false; // User cancelled, ignore scan
    }

    if (_localDatabase.containsKey(barcode)) {
      final localData = _localDatabase[barcode]!;
      _cartItems.add(Product(
        barcode: barcode,
        name: localData['name'],
        price: (localData['price'] as num).toDouble(),
      ));
      showScanToast(context, "${localData['name']} added to bill!");
      notifyListeners();
      return true;
    }

    try {
      final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json'),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          String globalName = data['product']['product_name'] ?? "Unknown Item";
          String? globalImage = data['product']['image_front_url'];

          double? setPrice = await _showPriceInputDialog(context, globalName);
          
          if (setPrice != null) {
            _localDatabase[barcode] = {'name': globalName, 'price': setPrice};
            await _saveDatabaseToDisk(); 
            
            _cartItems.add(Product(barcode: barcode, name: globalName, price: setPrice, imageUrl: globalImage));
            showScanToast(context, "$globalName registered successfully!");
            notifyListeners();
            return true;
          }
          return false;
        }
      }
    } catch (e) {
      debugPrint("Global API lookup timeout: $e");
    }

    return await _showManualEntryDialog(context, barcode);
  }

  void removeCartItem(String barcode, BuildContext context, String itemName) {
    _cartItems.removeWhere((item) => item.barcode == barcode);
    showScanToast(context, "$itemName removed from bill", isError: true);
    notifyListeners();
  }

  void finalizeCheckout() async {
    if (_cartItems.isEmpty) return;

    if (_isPrinterConnected) {
      await printReceipt();
    }

    String todayStr = DateTime.now().toIso8601String().split('T')[0];
    
    Map<String, dynamic> newSaleRecord = {
      'timestamp': DateTime.now().toIso8601String(),
      'total': totalCartAmount,
      'items': _cartItems.map((i) => {'name': i.name, 'qty': i.quantity, 'price': i.price}).toList(),
    };

    if (!_salesHistory.containsKey(todayStr)) {
      _salesHistory[todayStr] = [];
    }
    _salesHistory[todayStr]!.add(newSaleRecord);
    
    await _saveSalesToDisk();
    _calculateTodayMetrics();
    _cartItems.clear();
    notifyListeners();
  }

  Future<void> updateInventoryPrice(String barcode, double newPrice) async {
    if (_localDatabase.containsKey(barcode)) {
      _localDatabase[barcode]!['price'] = newPrice;
      await _saveDatabaseToDisk();
      notifyListeners();
    }
  }

  Future<void> deleteItemFromInventory(String barcode) async {
    if (_localDatabase.containsKey(barcode)) {
      _localDatabase.remove(barcode);
      await _saveDatabaseToDisk();
      notifyListeners();
    }
  }

  Future<void> printReceipt() async {
    if (!_isPrinterConnected) return;

    _bluetoothManager.printCustom("DINESH SHOP", 3, 1);
    _bluetoothManager.printCustom("ITER Campus Road, Bhubaneswar", 0, 1);
    _bluetoothManager.printCustom("Ph: +91 7854041120", 0, 1);
    _bluetoothManager.printCustom("--------------------------------", 0, 1);
    
    String timestamp = DateTime.now().toString().substring(0, 19);
    _bluetoothManager.printCustom("Date/Time: $timestamp", 0, 0);
    _bluetoothManager.printCustom("--------------------------------", 0, 1);

    _bluetoothManager.printCustom("ITEM          QTY   PRICE   TOTAL", 1, 0);
    _bluetoothManager.printCustom("--------------------------------", 0, 1);

    for (var item in _cartItems) {
      String paddedName = item.name.length > 12 ? item.name.substring(0, 12) : item.name.padRight(12);
      String qtyStr = item.quantity.toString().padRight(5);
      String priceStr = item.price.toStringAsFixed(0).padRight(7);
      String itemTotal = (item.price * item.quantity).toStringAsFixed(0);
      
      _bluetoothManager.printCustom("$paddedName $qtyStr $priceStr $itemTotal", 0, 0);
    }

    _bluetoothManager.printCustom("--------------------------------", 0, 1);
    _bluetoothManager.printCustom("GRAND TOTAL:       INR ${totalCartAmount.toStringAsFixed(2)}", 2, 2);
    _bluetoothManager.printCustom("--------------------------------", 0, 1);
    
    _bluetoothManager.printCustom("Thank You! Visit Again 😊", 1, 1);
    _bluetoothManager.printCustom("App engineered by Soumya", 0, 1);
    
    _bluetoothManager.printNewLine();
    _bluetoothManager.printNewLine();
    _bluetoothManager.paperCut(); 
  }

  // 🚀 FIXED: New Feature to print past invoices directly from the JSON map
  Future<void> printPastReceipt(Map<String, dynamic> sale) async {
    if (!_isPrinterConnected) return;

    _bluetoothManager.printCustom("DINESH SHOP", 3, 1);
    _bluetoothManager.printCustom("ITER Campus Road, Bhubaneswar", 0, 1);
    _bluetoothManager.printCustom("Ph: +91 7854041120", 0, 1);
    _bluetoothManager.printCustom("--------------------------------", 0, 1);

    String timestamp = sale['timestamp'].toString().substring(0, 19).replaceAll('T', ' ');
    _bluetoothManager.printCustom("Date: $timestamp", 0, 0);
    _bluetoothManager.printCustom("--------------------------------", 0, 1);

    _bluetoothManager.printCustom("ITEM          QTY   PRICE   TOTAL", 1, 0);
    _bluetoothManager.printCustom("--------------------------------", 0, 1);

    final itemsList = sale['items'] as List;
    for (var item in itemsList) {
      String name = item['name'];
      String paddedName = name.length > 12 ? name.substring(0, 12) : name.padRight(12);
      String qtyStr = item['qty'].toString().padRight(5);
      String priceStr = (item['price'] as num).toStringAsFixed(0).padRight(7);
      String itemTotal = ((item['price'] as num) * (item['qty'] as num)).toStringAsFixed(0);

      _bluetoothManager.printCustom("$paddedName $qtyStr $priceStr $itemTotal", 0, 0);
    }

    _bluetoothManager.printCustom("--------------------------------", 0, 1);
    _bluetoothManager.printCustom("GRAND TOTAL:       INR ${(sale['total'] as num).toStringAsFixed(2)}", 2, 2);
    _bluetoothManager.printCustom("--------------------------------", 0, 1);

    _bluetoothManager.printCustom("Thank You! Visit Again 😊", 1, 1);
    _bluetoothManager.printCustom("App engineered by Soumya", 0, 1);
    _bluetoothManager.printCustom("[DUPLICATE RECEIPT]", 0, 1); // Mark as duplicate for safety

    _bluetoothManager.printNewLine();
    _bluetoothManager.printNewLine();
    _bluetoothManager.paperCut();
  }

  Future<void> _saveDatabaseToDisk() async {
    if (_prefs != null) {
      await _prefs!.setString('local_products_db', jsonEncode(_localDatabase));
    }
  }

  Future<void> _saveSalesToDisk() async {
    if (_prefs != null) {
      await _prefs!.setString('sales_history_db', jsonEncode(_salesHistory));
    }
  }

  void _calculateTodayMetrics() {
    String todayStr = DateTime.now().toIso8601String().split('T')[0];
    if (_salesHistory.containsKey(todayStr)) {
      _checkoutCountToday = _salesHistory[todayStr]!.length;
      _totalSalesToday = _salesHistory[todayStr]!.fold(0.0, (sum, sale) => sum + (sale['total'] as num).toDouble());
    } else {
      _checkoutCountToday = 0;
      _totalSalesToday = 0.0;
    }
  }

  // 🚀 FIXED: The Duplicate Popup Logic UI Box
  Future<bool?> _showDuplicateScanDialog(BuildContext context, String itemName) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Duplicate Scan ⚠️", style: TextStyle(color: Colors.orange)),
        content: Text("You already scanned **$itemName**.\n\nDo you want to add another +1 to the cart?", style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Dismiss and do nothing
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), // Confirm increment
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: const Text("Add +1"),
          )
        ],
      ),
    );
  }

  Future<double?> _showPriceInputDialog(BuildContext context, String productName) async {
    double? enteredPrice;
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Global Match: $productName"),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Set Store Price (₹)", prefixText: "₹ "),
          onChanged: (value) => enteredPrice = double.tryParse(value),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, enteredPrice),
            child: const Text("Save & Add"),
          ),
        ],
      ),
    );
  }

  Future<bool> _showManualEntryDialog(BuildContext context, String barcode) async {
    String name = "";
    double price = 0.0;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("New Product Discovered"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(labelText: "Product Name"),
              onChanged: (value) => name = value,
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Price (₹)", prefixText: "₹ "),
              onChanged: (value) => price = double.tryParse(value) ?? 0.0,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (name.isNotEmpty && price > 0) {
                _localDatabase[barcode] = {'name': name, 'price': price};
                await _saveDatabaseToDisk(); 
                
                _cartItems.add(Product(barcode: barcode, name: name, price: price));
                showScanToast(context, "$name saved to inventory!");
                notifyListeners();
                Navigator.pop(context, true);
              } else {
                Navigator.pop(context, false);
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    ) ?? false;
  }

  // 🚀 Auto-Update Feature Variables
  static const String appVersion = "1.2.0"; // Current App Version
  
  bool _hasUpdate = false;
  bool get hasUpdate => _hasUpdate;
  
  bool _isCheckingUpdate = false;
  bool get isCheckingUpdate => _isCheckingUpdate;
  
  String _latestVersion = "";
  String get latestVersion => _latestVersion;
  
  String _updateDownloadUrl = "";
  String get updateDownloadUrl => _updateDownloadUrl;
  
  String _updateReleaseNotes = "";
  String get updateReleaseNotes => _updateReleaseNotes;

  Future<void> checkForUpdates() async {
    _isCheckingUpdate = true;
    notifyListeners();

    try {
      // First try cartsnap repository URL
      var response = await http.get(
        Uri.parse('https://api.github.com/repos/byteWizard-zero/cartsnap/releases/latest'),
      ).timeout(const Duration(seconds: 5));

      // Fallback to old smart_billing_app URL if cartsnap repository doesn't exist yet
      if (response.statusCode == 404) {
        response = await http.get(
          Uri.parse('https://api.github.com/repos/byteWizard-zero/smart_billing_app/releases/latest'),
        ).timeout(const Duration(seconds: 5));
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String tag = data['tag_name'] ?? "";
        
        if (tag.isNotEmpty && _isNewerVersion(tag, appVersion)) {
          _hasUpdate = true;
          _latestVersion = tag;
          _updateReleaseNotes = data['body'] ?? "No release notes provided.";
          
          // Try to find apk asset in the assets list
          final assets = data['assets'] as List?;
          if (assets != null && assets.isNotEmpty) {
            final apkAsset = assets.firstWhere(
              (asset) => asset['name'].toString().toLowerCase().endsWith('.apk'),
              orElse: () => null,
            );
            if (apkAsset != null) {
              _updateDownloadUrl = apkAsset['browser_download_url'] ?? "";
            }
          }
          
          // If no specific APK found, fall back to the release HTML page
          if (_updateDownloadUrl.isEmpty) {
            _updateDownloadUrl = data['html_url'] ?? "";
          }
        }
      }
    } catch (e) {
      debugPrint("Auto-update check exception: $e");
    } finally {
      _isCheckingUpdate = false;
      notifyListeners();
    }
  }

  bool _isNewerVersion(String latest, String current) {
    final cleanLatest = latest.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
    final cleanCurrent = current.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
    
    List<int> latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    int maxLength = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;
    for (int i = 0; i < maxLength; i++) {
      int latestVal = i < latestParts.length ? latestParts[i] : 0;
      int currentVal = i < currentParts.length ? currentParts[i] : 0;
      if (latestVal > currentVal) return true;
      if (latestVal < currentVal) return false;
    }
    return false;
  }
  
  void dismissUpdateNotification() {
    _hasUpdate = false;
    notifyListeners();
  }
}