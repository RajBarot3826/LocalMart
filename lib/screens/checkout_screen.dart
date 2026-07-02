import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/cart_manager.dart';
import '../utils/address_manager.dart';
import '../utils/api_handler.dart';
import 'order_success_screen.dart';
import '../services/notification_service.dart';
import '../services/ai_assistant_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _platform = MethodChannel('com.example.localmart/upi');
  int _currentStep = 1; // 1: Address, 2: Summary+Payment
  bool _isPlacingOrder = false;
  String _selectedPaymentMethod = 'COD'; // 'COD' or 'UPI'

  // Real user data
  String _userName = '';
  String _userPhone = '';

  // Add address form
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedLabel = 'HOME';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone') ?? '';
    await AddressManager().loadForUser(phone);
    setState(() {
      _userName = prefs.getString('userName') ?? 'User';
      _userPhone = phone;
    });
  }

  Future<Position?> _getUserLocation({bool forcePrompt = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please enable GPS/Location services on your device."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          final bool? proceed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text("Location Access Required"),
              content: const Text(
                "LocalMart needs your location permission to calculate delivery fees, find stores near you, and guide the rider to your delivery address.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("CANCEL"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: const Text("ALLOW"),
                ),
              ],
            ),
          );
          if (proceed != true) return null;
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Location permission denied. Cannot retrieve location."),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text("Location Permission Blocked"),
              content: const Text(
                "Location permission is permanently denied. Please enable it in App Settings to select your delivery address.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("CANCEL"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Geolocator.openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: const Text("OPEN SETTINGS"),
                ),
              ],
            ),
          );
        }
        return null;
      }

      // Try fast last known location fallback
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 4), onTimeout: () {
        throw TimeoutException("Location request timed out");
      });
    } catch (e) {
      debugPrint("Error fetching user location: $e");
      return null;
    }
  }

  Future<String> _triggerUpiPayment(double amount) async {
    final String upiId = CartManager().adminUpiId; // Loaded dynamically from server (fallback: 9409630896@upi)
    final String payeeName = "LocalMart";
    final String amountStr = amount.toStringAsFixed(2);

    // UPI-safe encoder: GPay/PhonePe reject %20, NPCI spec uses + for spaces
    String upiEncode(String value) => Uri.encodeComponent(value).replaceAll('%20', '+');

    // Build complete UPI deep link with standard P2P parameters (pa, pn, am, cu)
    // Excluding merchant-only parameters (tn, tr) to prevent security blocks on personal VPAs
    final String url = "upi://pay"
        "?pa=${upiEncode(upiId)}"
        "&pn=${upiEncode(payeeName)}"
        "&am=$amountStr"
        "&cu=INR";

    debugPrint("🔗 UPI Payment URL: $url");

    try {
      // 1. Attempt to launch via native MethodChannel to get the payment status
      final String? result = await _platform.invokeMethod<String>(
        'startUpiPayment',
        {'upiUri': url},
      );
      debugPrint("📱 UPI native result: $result");
      return result ?? "Status=FAILURE&responseCode=ZD";
    } catch (e) {
      debugPrint("Native UPI channel failed/unavailable: $e. Falling back to deep-link launch.");
      // 2. Fallback to deep-link URL launch if native channel is unsupported
      final Uri uri = Uri.parse(url);
      try {
        final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          throw Exception("Could not launch UPI app");
        }
      } catch (launchError) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception("No UPI apps found on your device. Please install Google Pay, PhonePe, or Paytm.");
        }
      }
      return "FALLBACK_MANUAL"; // Indicates we must ask for manual UTR
    }
  }

  Future<void> _placeOrder() async {
    final address = AddressManager().selectedAddress;
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a delivery address first')),
      );
      setState(() => _currentStep = 1);
      return;
    }

    final cart = CartManager();
    String paymentMethodString = _selectedPaymentMethod;

    if (_selectedPaymentMethod == 'UPI') {
      setState(() => _isPlacingOrder = true);
      try {
        final String rawResult = await _triggerUpiPayment(cart.totalAmount);
        debugPrint("📱 UPI app redirection rawResult: $rawResult");

        if (rawResult != "FALLBACK_MANUAL") {
          final Map<String, String> upiResponse = {};
          for (final part in rawResult.split('&')) {
            final kv = part.split('=');
            if (kv.length == 2) {
              upiResponse[kv[0].trim().toLowerCase()] = kv[1].trim();
            }
          }
          final String upiStatus = upiResponse['status']?.toUpperCase() ?? '';
          final String? txnId = upiResponse['txnid'] ?? upiResponse['approvalrefno'];
          
          if (upiStatus == 'SUCCESS' || upiStatus == 'SUBMITTED') {
            final String utr = txnId ?? 'UPI-${DateTime.now().millisecondsSinceEpoch}';
            paymentMethodString = 'UPI (Ref: $utr)';
          } else {
            if (!mounted) return;
            setState(() => _isPlacingOrder = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment not completed or failed in UPI app.'),
                backgroundColor: Colors.red,
              ),
            );
            return; // DO NOT place order
          }
        } else {
          // Fallback if status not returned (e.g. emulator, or direct launch return)
          paymentMethodString = 'UPI (Pending Manual Verification)';
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('UPI payment failed: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
        return; // DO NOT place order
      }
    }

    setState(() => _isPlacingOrder = true);

    try {
      double? lat = address.latitude;
      double? lng = address.longitude;
      if (lat == null || lng == null) {
        final pos = await _getUserLocation(forcePrompt: true);
        if (!mounted) return;
        if (pos != null) {
          lat = pos.latitude;
          lng = pos.longitude;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to calculate delivery fee and place your order.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isPlacingOrder = false);
          return;
        }
      }

      final orderData = {
        'user_phone': _userPhone,
        'user_name': _userName,
        'store_id': cart.currentStoreId ?? '',
        'store_name': cart.currentStoreName ?? 'Store',
        'delivery_address': '${address.name}, ${address.fullAddress} (Phone: ${address.phone})',
        'payment_method': paymentMethodString,
        'subtotal': cart.itemsTotal.toStringAsFixed(2),
        'delivery_fee': cart.deliveryFee.toStringAsFixed(2),
        'total_amount': cart.totalAmount.toStringAsFixed(2),
        'delivery_lat': lat.toString(),
        'delivery_lng': lng.toString(),
        'items': cart.items.map((item) => {
          'product_id': item.product.id,
          'product_name': item.product.name,
          'quantity': item.quantity,
          'price': item.product.price,
        }).toList(),
      };

      final response = await ApiHandler.postJson('place_order.php', orderData);

      final storeName = cart.currentStoreName ?? 'Store';
      String orderId = 'LM${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      if (response == null) {
        throw Exception("No response from server");
      }
      
      if (response['status'] != 'success' && response['success'] != true) {
        throw Exception(response['message'] ?? "Server rejected the order");
      }

      orderId = response['order_id']?.toString() ?? orderId;

      // Trigger instant Order Placed Notification with AI message
      final aiMessage = AIAssistantService().generateOrderStatusMessage(
        status: 'placed',
        storeName: storeName,
        orderId: orderId,
      );

      NotificationService().showNotification(
        id: orderId.hashCode.abs() % 100000,
        title: "🎉 Order Placed #$orderId",
        body: aiMessage,
        payload: orderId,
      );

      cart.clearCart();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            storeName: storeName,
            orderId: orderId,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      debugPrint("❌ Place order error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _showAddAddressSheet() {
    _nameCtrl.text = _userName;
    _phoneCtrl.text = _userPhone;
    _addressCtrl.clear();
    _cityCtrl.clear();
    _pincodeCtrl.clear();
    _selectedLabel = 'HOME';

    bool isLocating = false;
    double? capturedLat;
    double? capturedLng;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add New Address', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.dark)),
                const SizedBox(height: 15),
                
                // Use GPS Location Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLocating ? null : () async {
                      setSheetState(() => isLocating = true);
                      Position? pos = await _getUserLocation(forcePrompt: true);
                      setSheetState(() => isLocating = false);
                      if (pos != null) {
                        setSheetState(() {
                          capturedLat = pos.latitude;
                          capturedLng = pos.longitude;
                          if (_addressCtrl.text.isEmpty) {
                            _addressCtrl.text = "Live Location (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})";
                          }
                          if (_cityCtrl.text.isEmpty) _cityCtrl.text = "Ahmedabad";
                          if (_pincodeCtrl.text.isEmpty) _pincodeCtrl.text = "380001";
                        });
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('📍 Captured Location: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                    icon: isLocating 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.my_location, color: Colors.white, size: 18),
                    label: Text(isLocating ? "Detecting GPS Location..." : "📍 Use My Current GPS Location", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Label Selector
                Row(
                  children: ['HOME', 'OFFICE', 'OTHER'].map((label) {
                    final isSelected = _selectedLabel == label;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(label, style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.primary,
                          fontWeight: FontWeight.bold, fontSize: 12,
                        )),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: isSelected ? AppTheme.primary : Colors.grey.shade300),
                        onSelected: (val) => setSheetState(() => _selectedLabel = label),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),
                _buildField('Full Name', _nameCtrl, Icons.person),
                _buildField('Phone Number', _phoneCtrl, Icons.phone, keyboardType: TextInputType.phone),
                _buildField('Full Address', _addressCtrl, Icons.location_on, maxLines: 2),
                _buildField('City', _cityCtrl, Icons.location_city),
                _buildField('Pincode', _pincodeCtrl, Icons.pin, keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_nameCtrl.text.isEmpty || _addressCtrl.text.isEmpty || _cityCtrl.text.isEmpty || _pincodeCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all fields')),
                        );
                        return;
                      }
                      // Fetch coordinates if not already captured
                      Position? pos = capturedLat != null && capturedLng != null 
                        ? null 
                        : await _getUserLocation();
                      AddressManager().addAddress(SavedAddress(
                        label: _selectedLabel,
                        name: _nameCtrl.text.trim(),
                        address: _addressCtrl.text.trim(),
                        city: _cityCtrl.text.trim(),
                        pincode: _pincodeCtrl.text.trim(),
                        phone: _phoneCtrl.text.trim(),
                        latitude: capturedLat ?? pos?.latitude,
                        longitude: capturedLng ?? pos?.longitude,
                      ));
                      if (!mounted) return;
                      Navigator.pop(context);
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String hint, TextEditingController ctrl, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          _currentStep == 1 ? 'Delivery Address' : 'Order Summary',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBuilder(
        animation: AddressManager(),
        builder: (context, _) {
          return Column(
            children: [
              // Step Indicator
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                child: Row(
                  children: [
                    _stepChip(1, 'Address'),
                    _stepLine(1),
                    _stepChip(2, 'Summary'),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _currentStep == 1 ? _buildAddressStep() : _buildSummaryStep(),
                ),
              ),
              // Bottom Bar
              _buildBottomBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _stepChip(int step, String title) {
    final isActive = _currentStep >= step;
    final isDone = _currentStep > step;
    return GestureDetector(
      onTap: () {
        if (step < _currentStep) setState(() => _currentStep = step);
      },
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primary : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text('$step', style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(
            color: isActive ? AppTheme.dark : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  Widget _stepLine(int step) {
    return Expanded(
      child: Container(
        height: 2, margin: const EdgeInsets.symmetric(horizontal: 12),
        color: _currentStep > step ? AppTheme.primary : Colors.grey.shade300,
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STEP 1: ADDRESS
  // ═══════════════════════════════════════════
  Widget _buildAddressStep() {
    final addresses = AddressManager().addresses;
    final selectedIdx = AddressManager().selectedIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.location_on, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Saved Addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.dark)),
          ],
        ),
        const SizedBox(height: 15),

        if (addresses.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFEAF5EE), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Center(
              child: Text('No addresses saved yet.\nTap the button below to add one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
          ),

        ...addresses.asMap().entries.map((entry) {
          final idx = entry.key;
          final addr = entry.value;
          final isSelected = idx == selectedIdx;

          return GestureDetector(
            onTap: () => AddressManager().selectAddress(idx),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(addr.label, style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(addr.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(addr.fullAddress, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 5),
                      Text(addr.phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 8),
                    Text('✓ Delivering Here', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 10),
        // Add New Address Button
        GestureDetector(
          onTap: _showAddAddressSheet,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary, style: BorderStyle.solid, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('Add New Address', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // STEP 2: SUMMARY + PAYMENT
  // ═══════════════════════════════════════════
  Widget _buildSummaryStep() {
    final cart = CartManager();
    final address = AddressManager().selectedAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Delivery To
        if (address != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFEAF5EE), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deliver to: ${address.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(address.fullAddress, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentStep = 1),
                  child: const Text('Change', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

        const SizedBox(height: 15),

        // Order Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFEAF5EE), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Order Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dark)),
                ],
              ),
              const SizedBox(height: 15),
              ...cart.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text('🛒 ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('Qty: ${item.quantity}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('₹${((double.tryParse(item.product.price) ?? 0) * item.quantity).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ],
                ),
              )),
            ],
          ),
        ),

        const SizedBox(height: 15),

        // Price Details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFEAF5EE), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('🏷️ ', style: TextStyle(fontSize: 16)),
                  Text('Price Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dark)),
                ],
              ),
              const Divider(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Items Total (${cart.totalItems} items)'),
                  Text('₹${cart.itemsTotal.toStringAsFixed(0)}'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Delivery Fee (${cart.estimatedDistanceKm.toStringAsFixed(1)} km)'),
                  Text(
                    cart.deliveryFee > 0 ? '₹${cart.deliveryFee.toStringAsFixed(0)}' : 'FREE',
                    style: TextStyle(
                      color: cart.deliveryFee > 0 ? AppTheme.dark : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('₹${cart.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),

        // Payment Method Selector
        const Row(
          children: [
            Text('💳 ', style: TextStyle(fontSize: 16)),
            Text('Select Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dark)),
          ],
        ),
        const SizedBox(height: 12),

        // Cash on Delivery Card
        GestureDetector(
          onTap: () => setState(() => _selectedPaymentMethod = 'COD'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedPaymentMethod == 'COD' ? AppTheme.primary : Colors.grey.shade300,
                width: _selectedPaymentMethod == 'COD' ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.money, color: Colors.green.shade700, size: 28),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cash on Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Pay when you receive the order', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
                if (_selectedPaymentMethod == 'COD')
                  Icon(Icons.check_circle, color: AppTheme.primary)
                else
                  Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // UPI Payment Card
        GestureDetector(
          onTap: () => setState(() => _selectedPaymentMethod = 'UPI'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedPaymentMethod == 'UPI' ? AppTheme.primary : Colors.grey.shade300,
                width: _selectedPaymentMethod == 'UPI' ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.qr_code_scanner, color: Colors.blue.shade700, size: 28),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Instant UPI Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Pay instantly via GPay, PhonePe, Paytm', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
                if (_selectedPaymentMethod == 'UPI')
                  Icon(Icons.check_circle, color: AppTheme.primary)
                else
                  Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBottomBar() {
    final cart = CartManager();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('₹${cart.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.dark)),
                Text('${cart.totalItems} items', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            ElevatedButton(
              onPressed: _isPlacingOrder ? null : () {
                if (_currentStep == 1) {
                  if (AddressManager().addresses.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please add a delivery address first')),
                    );
                    return;
                  }
                  setState(() => _currentStep = 2);
                } else {
                  _placeOrder();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isPlacingOrder
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _currentStep == 1 ? 'Continue' : 'Confirm Order',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
