import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';

class InvoiceScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const InvoiceScreen({super.key, required this.orderData});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isExporting = false;

  Future<void> _captureAndShare() async {
    setState(() => _isExporting = true);
    try {
      // Add a tiny delay to ensure the UI is fully built and refreshed
      await Future.delayed(const Duration(milliseconds: 100));
      
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        
        await Share.shareXFiles(
          [XFile.fromData(pngBytes, mimeType: 'image/png', name: 'invoice_${widget.orderData['order_id']}.png')],
          text: 'Invoice for Order #${widget.orderData['order_id']} from ${widget.orderData['store_name']}',
        );
      }
    } catch (e) {
      debugPrint("Error sharing invoice: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to share invoice')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.orderData;
    final orderId = order['order_id']?.toString() ?? 'N/A';
    final storeName = order['store_name']?.toString() ?? 'LocalMart Store';
    final totalAmount = order['total_amount']?.toString() ?? '0';
    final deliveryFee = order['delivery_fee']?.toString() ?? '0';
    final date = order['created_at']?.toString() ?? order['date']?.toString() ?? '';
    final phone = order['user_phone']?.toString() ?? '';
    final address = order['address']?.toString() ?? '';
    final items = order['items'];

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text('Invoice', style: TextStyle(color: AppTheme.dark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.dark),
        actions: [
          IconButton(
            icon: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.share, color: AppTheme.primary),
            onPressed: _isExporting ? null : _captureAndShare,
            tooltip: 'Share Invoice',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                key: _globalKey,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid)), // Dashed effect is hard in native flutter without custom painter, using solid
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long, size: 40, color: AppTheme.primary),
                            const SizedBox(height: 10),
                            const Text('TAX INVOICE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppTheme.dark)),
                            const SizedBox(height: 5),
                            Text(storeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Order Info
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Order ID:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text('#$orderId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Date:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Customer Info
                            if (phone.isNotEmpty || address.isNotEmpty) ...[
                              const Text('BILLED TO:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              if (phone.isNotEmpty) Text('Phone: $phone', style: const TextStyle(fontSize: 14)),
                              if (address.isNotEmpty) Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(address, style: const TextStyle(fontSize: 14)),
                              ),
                              const SizedBox(height: 20),
                            ],

                            const Divider(thickness: 1.5),
                            const SizedBox(height: 10),

                            // Table Header
                            const Row(
                              children: [
                                Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(),
                            const SizedBox(height: 10),

                            // Items List
                            if (items is List)
                              ...items.map((item) {
                                final itemName = item['product_name']?.toString() ?? item['name']?.toString() ?? 'Item';
                                final qty = item['quantity']?.toString() ?? '1';
                                final price = item['price']?.toString() ?? '0';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 3, child: Text(itemName, style: const TextStyle(fontSize: 14))),
                                      Expanded(flex: 1, child: Text('x$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14))),
                                      Expanded(flex: 2, child: Text('₹$price', textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                                    ],
                                  ),
                                );
                              }),

                            const SizedBox(height: 10),
                            const Divider(thickness: 1.5),
                            const SizedBox(height: 10),

                            // Totals
                            if (double.tryParse(deliveryFee) != null && double.parse(deliveryFee) > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Delivery Fee', style: TextStyle(color: Colors.grey)),
                                    Text('₹$deliveryFee'),
                                  ],
                                ),
                              ),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL PAID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.dark)),
                                Text('₹$totalAmount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primary)),
                              ],
                            ),
                            
                            const SizedBox(height: 40),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.verified, color: Colors.green.shade400, size: 30),
                                  const SizedBox(height: 8),
                                  const Text('Thank you for your order!', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 4),
                                  const Text('LocalMart App', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom Share Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _captureAndShare,
                icon: _isExporting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.download, color: Colors.white),
                label: Text(_isExporting ? 'Generating...' : 'Download / Share Receipt', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
