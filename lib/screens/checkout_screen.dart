import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/cart_manager.dart';
import '../utils/address_manager.dart';
import '../utils/api_handler.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _currentStep = 1; // 1: Address, 2: Summary+Payment
  bool _isPlacingOrder = false;

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

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone') ?? '';
    await AddressManager().loadForUser(phone);
    setState(() {
      _userName = prefs.getString('userName') ?? 'User';
      _userPhone = phone;
    });
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

    setState(() => _isPlacingOrder = true);

    try {
      final cart = CartManager();
      final orderData = {
        'user_phone': _userPhone,
        'user_name': _userName,
        'store_id': cart.currentStoreId ?? '',
        'store_name': cart.currentStoreName ?? 'Store',
        'delivery_address': '${address.name}, ${address.fullAddress} (Phone: ${address.phone})',
        'payment_method': 'COD',
        'subtotal': cart.itemsTotal.toStringAsFixed(2),
        'delivery_fee': cart.deliveryFee.toStringAsFixed(2),
        'total_amount': cart.totalAmount.toStringAsFixed(2),
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
                const SizedBox(height: 20),
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
                    onPressed: () {
                      if (_nameCtrl.text.isEmpty || _addressCtrl.text.isEmpty || _cityCtrl.text.isEmpty || _pincodeCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all fields')),
                        );
                        return;
                      }
                      AddressManager().addAddress(SavedAddress(
                        label: _selectedLabel,
                        name: _nameCtrl.text.trim(),
                        address: _addressCtrl.text.trim(),
                        city: _cityCtrl.text.trim(),
                        pincode: _pincodeCtrl.text.trim(),
                        phone: _phoneCtrl.text.trim(),
                      ));
                      Navigator.pop(ctx);
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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

        // Payment Method
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
              Icon(Icons.check_circle, color: AppTheme.primary),
            ],
          ),
        ),
        const SizedBox(height: 30),
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
