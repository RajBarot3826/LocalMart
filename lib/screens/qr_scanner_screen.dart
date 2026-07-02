 import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../models/shop_model.dart';
import '../utils/api_handler.dart';
import '../utils/locale_provider.dart';
import 'product_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool isScanning = true;

  void onDetect(BarcodeCapture capture) async {
    if (!isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() => isScanning = false);
        _handleQrCode(code);
      }
    }
  }

  Future<void> _handleQrCode(String code) async {
    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    try {
      final data = await ApiHandler.get('stores.php');

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // Close loading

      // Parse stores from API response: {"status":true,"stores":[...]}
      List<dynamic> dataList = [];
      if (data is Map && data.containsKey('stores')) {
        dataList = data['stores'] ?? [];
      } else if (data is List) {
        dataList = data;
      }

      final List<Shop> shops = dataList.map((json) => Shop.fromJson(json)).toList();
      
      // The QR code from your admin panel is the qr_code_token (e.g., "shop_398dea31dff2")
      // or it could be the store id
      Shop? foundShop;
      try {
        foundShop = shops.firstWhere(
          (s) {
            if (s.qrCodeToken.isNotEmpty && code == s.qrCodeToken) return true;
            if (s.id == code) return true;
            if (s.qrCodeToken.isNotEmpty && code.contains(s.qrCodeToken)) return true;
            if (code.contains('shop_id=${s.id}') || code.contains('id=${s.id}')) return true;
            return false;
          },
        );
      } catch (e) {
        // No match found
      }

      if (foundShop != null) {
        final shop = foundShop; // capture non-null for closure
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProductScreen(
                shop: {
                  "id": shop.id,
                  "name": shop.name,
                  "category": shop.category,
                  "rating": shop.rating,
                  "distance": shop.distance,
                  "open": shop.isOpen,
                  "owner": shop.owner,
                  "phone": shop.phone,
                  "address": shop.address,
                  "description": shop.description,
                  "logoUrl": shop.logoUrl,
                  "delivery_enabled": shop.deliveryEnabled,
                  "delivery_fee_type": shop.deliveryFeeType,
                  "delivery_fee": shop.deliveryFee,
                  "latitude": shop.latitude,
                  "longitude": shop.longitude,
                },
              ),
            ),
          );
        }
      } else {
        _showError("Store not found for QR code: $code");
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showError("Unable to verify QR code. Please try manual search.");
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() => isScanning = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleProvider.tr('scan_store_qr'), style: const TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
              facing: CameraFacing.back,
            ),
            onDetect: onDetect,
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primary, width: 4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Align QR Code within the frame",
                style: TextStyle(color: Colors.white, fontSize: 16, backgroundColor: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
