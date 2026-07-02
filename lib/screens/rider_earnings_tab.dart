import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/api_handler.dart';

class RiderEarningsTab extends StatefulWidget {
  const RiderEarningsTab({super.key});

  @override
  State<RiderEarningsTab> createState() => _RiderEarningsTabState();
}

class _RiderEarningsTabState extends State<RiderEarningsTab> {
  String selectedFilter = 'This Week';
  int riderId = 0;
  bool isLoading = true;
  Map<String, dynamic>? withdrawalStatus;
  Map<String, dynamic> earningsData = {
    'total': 0,
    'deliveries': 0,
    'rating': '0.0',
    'per_order': 0,
    'delivery_fees': 0,
    'tips': 0,
    'platform_fee': 0,
    'orders': [],
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    riderId = prefs.getInt('userId') ?? 0;
    
    if (riderId > 0) {
      _fetchEarnings();
      _fetchWithdrawalStatus();
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchWithdrawalStatus() async {
    try {
      final response = await ApiHandler.get('get_withdrawal_status.php?rider_id=$riderId');
      if (mounted && response != null && (response['status'] == true || response['status'] == 'success')) {
        setState(() {
          withdrawalStatus = response;
        });
      }
    } catch (e) {
      debugPrint("Error fetching withdrawal status: $e");
    }
  }

  Future<void> _fetchEarnings() async {
    setState(() => isLoading = true);
    
    String filterParam = 'week';
    if (selectedFilter == 'Today') filterParam = 'today';
    if (selectedFilter == 'This Month') filterParam = 'month';

    final response = await ApiHandler.get('rider_earnings.php?rider_id=$riderId&filter=$filterParam');
    if (mounted) {
      setState(() {
        isLoading = false;
        if (response != null && response['status'] == true && response['data'] != null) {
          earningsData = response['data'];
        }
      });
    }
  }

  void _openWithdrawalSheet(double availableBal) {
    final amountController = TextEditingController(text: availableBal > 0 ? availableBal.toStringAsFixed(2) : "");
    final bankController = TextEditingController();
    final accController = TextEditingController();
    final ifscController = TextEditingController();
    final upiController = TextEditingController();
    final holderController = TextEditingController();
    String method = 'Bank Transfer';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 25),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Request Wallet Payout", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Available Balance:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      Text("₹${availableBal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Withdrawal Amount (₹)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
                ),
                const SizedBox(height: 15),
                const Text("Select Payment Method", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("Bank Transfer"),
                        selected: method == 'Bank Transfer',
                        onSelected: (val) => setSheetState(() => method = 'Bank Transfer'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("UPI ID"),
                        selected: method == 'UPI',
                        onSelected: (val) => setSheetState(() => method = 'UPI'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: holderController,
                  decoration: const InputDecoration(labelText: "Account Holder Name", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 10),
                if (method == 'Bank Transfer') ...[
                  TextField(
                    controller: bankController,
                    decoration: const InputDecoration(labelText: "Bank Name", border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: accController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Account Number", border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ifscController,
                    decoration: const InputDecoration(labelText: "IFSC Code", border: OutlineInputBorder(), prefixIcon: Icon(Icons.code)),
                  ),
                ] else ...[
                  TextField(
                    controller: upiController,
                    decoration: const InputDecoration(labelText: "UPI ID (e.g. 9876543210@upi)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code)),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () async {
                      final reqAmt = double.tryParse(amountController.text) ?? 0;
                      if (reqAmt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid amount")));
                        return;
                      }
                      if (reqAmt > availableBal) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Amount exceeds available balance (₹${availableBal.toStringAsFixed(2)})")));
                        return;
                      }
                      if (holderController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter account holder name")));
                        return;
                      }

                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                      final res = await ApiHandler.post('request_withdrawal.php', {
                        'rider_id': riderId.toString(),
                        'amount': reqAmt.toString(),
                        'payment_method': method,
                        'bank_name': bankController.text,
                        'account_number': accController.text,
                        'ifsc_code': ifscController.text,
                        'upi_id': upiController.text,
                        'account_holder': holderController.text,
                      });
                      if (mounted) {
                        nav.pop();
                        if (res != null && res['status'] == true) {
                          messenger.showSnackBar(SnackBar(content: Text(res['message'] ?? "Request submitted!"), backgroundColor: Colors.green));
                          _fetchWithdrawalStatus();
                        } else {
                          messenger.showSnackBar(SnackBar(content: Text(res?['message'] ?? "Failed to submit request"), backgroundColor: Colors.red));
                        }
                      }
                    },
                    child: const Text("Submit Payout Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletBal = double.tryParse(withdrawalStatus?['wallet_balance']?.toString() ?? '0') ?? 0.0;
    final canWithdraw = withdrawalStatus?['can_withdraw'] == true;
    final daysRemaining = int.tryParse(withdrawalStatus?['days_remaining']?.toString() ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Earnings & Wallet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
            onPressed: () {
              if (canWithdraw) {
                _openWithdrawalSheet(walletBal);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(withdrawalStatus?['error_message']?.toString() ?? "Withdrawal locked!"),
                  backgroundColor: Colors.orange,
                ));
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Green Banner
            Container(
              width: double.infinity,
              color: AppTheme.primary,
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 25),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(isLoading ? "..." : "₹${earningsData['total']}", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 5),
                        Text("$selectedFilter's Total", style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _statBox("${earningsData['deliveries']}", "Deliveries")),
                      const SizedBox(width: 10),
                      Expanded(child: _statBox("${earningsData['rating']}★", "Rating")),
                      const SizedBox(width: 10),
                      Expanded(child: _statBox("₹${earningsData['per_order']}", "Per Order")),
                    ],
                  ),
                ],
              ),
            ),

            // 15-Day Wallet Payout Card
            Container(
              margin: const EdgeInsets.all(15),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.green, size: 22),
                          SizedBox(width: 8),
                          Text("Rider Wallet Balance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                        child: const Text("15-Day Cycle", style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("₹${walletBal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canWithdraw ? AppTheme.primary : Colors.grey.shade400,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: canWithdraw ? () => _openWithdrawalSheet(walletBal) : null,
                        icon: Icon(canWithdraw ? Icons.send : Icons.lock, size: 16, color: Colors.white),
                        label: Text(
                          canWithdraw 
                              ? "Withdraw" 
                              : (daysRemaining > 0 ? "Locked ($daysRemaining d)" : "Locked"),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (!canWithdraw) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              withdrawalStatus?['error_message']?.toString() ?? 
                                  "Withdrawal locked! Next withdrawal unlocks in $daysRemaining day(s).",
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Filters
            Container(
              margin: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Expanded(child: _filterBtn('Today')),
                  Expanded(child: _filterBtn('This Week')),
                  Expanded(child: _filterBtn('This Month')),
                ],
              ),
            ),

            if (isLoading)
              const Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator())
            else ...[
              // Breakdown
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 15),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${selectedFilter.toUpperCase()}'S BREAKDOWN", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                        const Text("Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Delivery Fees (${earningsData['deliveries']} orders)", style: const TextStyle(fontSize: 14)),
                        Text("+₹${earningsData['delivery_fees']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Tips Received", style: TextStyle(color: Colors.green)),
                        Text("+₹${earningsData['tips']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Platform Fee", style: TextStyle(color: Colors.grey)),
                        Text("-₹${earningsData['platform_fee']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(""),
                        Text("₹${earningsData['total']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),

              // Recent Orders
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("RECENT ORDERS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 15),
                    ...(earningsData['orders'] as List? ?? []).map<Widget>((o) {
                      return _orderItem("Order #${o['id']}", "${o['date']}", "+₹${o['earned']}", o['is_cancelled'] ? "Cancelled" : "Fee + Tip");
                    }),
                    if ((earningsData['orders'] as List? ?? []).isEmpty)
                      const Text("No orders found for this period", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _statBox(String val, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _filterBtn(String text) {
    bool isSelected = selectedFilter == text;
    return GestureDetector(
      onTap: () {
        setState(() => selectedFilter = text);
        _fetchEarnings();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _orderItem(String title, String subtitle, String price, String subprice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 5),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              const SizedBox(height: 2),
              Text(subprice, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
