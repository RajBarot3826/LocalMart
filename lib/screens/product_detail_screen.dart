import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../utils/locale_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _callStore() async {
    final phone = (widget.product["storePhone"] ?? "").toString().replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No store phone number available")),
      );
      return;
    }
    try {
      await launchUrl(Uri.parse('tel:$phone'));
    } catch (e) {
      debugPrint("❌ Call error: $e");
    }
  }

  Future<void> _shareProduct() async {
    try {
      final name = widget.product["name"] ?? "Product";
      final price = widget.product["price"] ?? "";
      final storeName = widget.product["storeName"] ?? "Store";
      final desc = widget.product["description"] ?? "";

      final text = "Check out this product on LocalMart!\n\n"
          "📦 *$name*\n"
          "💰 Price: $price\n"
          "🏪 Sold by: $storeName\n\n"
          "$desc\n\n"
          "Download LocalMart app to buy this!";

      await Share.share(text);
    } catch (e) {
      debugPrint("❌ Share error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // PRODUCT IMAGE HEADER
              SliverAppBar(
                expandedHeight: 350,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppTheme.primary,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      // Background Graphics
                      Container(
                        color: Colors.white,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      Positioned(
                        top: -50,
                        right: -50,
                        child: CircleAvatar(
                          radius: 120,
                          backgroundColor: AppTheme.background.withOpacity(0.5),
                        ),
                      ),
                      Positioned(
                        bottom: 40,
                        left: -30,
                        child: CircleAvatar(
                          radius: 80,
                          backgroundColor: AppTheme.primary.withOpacity(0.05),
                        ),
                      ),
                      // Main Product Icon or Image
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        padding: const EdgeInsets.only(top: 60, bottom: 30),
                        child: Hero(
                          tag: widget.product["name"],
                          child: widget.product["imageUrl"] != null && widget.product["imageUrl"].toString().isNotEmpty
                              ? Image.network(
                                  widget.product["imageUrl"],
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => Icon(
                                    widget.product["image"] as IconData,
                                    size: 180,
                                    color: AppTheme.primary,
                                  ),
                                )
                              : Icon(
                                  widget.product["image"] as IconData,
                                  size: 180,
                                  color: AppTheme.primary,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // PRODUCT CONTENT
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -10))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              LocaleProvider.tr('in_stock'),
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Name & Price
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  LocaleProvider.tr(widget.product["name"]),
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.dark,
                                  ),
                                ),
                              ),
                              Text(
                                widget.product["price"],
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.storefront, size: 20, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Text(
                                "${LocaleProvider.tr('sold_by')} ${LocaleProvider.tr(widget.product["storeName"] ?? 'unknown_store')}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _callStore,
                                  icon: const Icon(Icons.call, color: Colors.white),
                                  label: Text(LocaleProvider.tr('call_now'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    elevation: 5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: IconButton(
                                  onPressed: _shareProduct,
                                  icon: const Icon(Icons.share, color: Colors.blue),
                                  iconSize: 28,
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // DYNAMIC SPECIFICATIONS (Only shows if backend provides the data)
                          if (_hasAnySpecs()) ...[
                            Text(
                              LocaleProvider.tr('product_details'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.dark,
                              ),
                            ),
                            const SizedBox(height: 20),
                            buildDynamicSpecs(),
                            const SizedBox(height: 35),
                          ],

                          // DESCRIPTION
                          Text(
                            LocaleProvider.tr('product_description'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.dark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (widget.product["description"] ?? "").toString().isNotEmpty 
                                ? widget.product["description"].toString()
                                : "Get this premium quality product from your nearest local mart. We ensure the freshest stock and competitive pricing for all our local customers.",
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.6,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 100), // Padding for bottom
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // CUSTOM BACK BUTTON (Always Visible)
          Positioned(
            top: 50,
            left: 20,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.dark, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasAnySpecs() {
    final p = widget.product;
    return p.containsKey('weight') || p.containsKey('type') || 
           p.containsKey('shelf_life') || p.containsKey('grade') ||
           p.containsKey('brand') || p.containsKey('warranty') || 
           p.containsKey('battery') || p.containsKey('ram') || 
           p.containsKey('processor') || p.containsKey('display');
  }

  Widget buildDynamicSpecs() {
    final p = widget.product;
    List<Widget> specWidgets = [];

    // Dynamic specifications sent from the backend
    if (p['specifications'] != null) {
      if (p['specifications'] is Map) {
        (p['specifications'] as Map).forEach((key, value) {
          specWidgets.add(specItem(Icons.label_important_outline_rounded, LocaleProvider.tr(key.toString()), LocaleProvider.tr(value.toString())));
        });
      } else if (p['specifications'] is List) {
        for (var spec in (p['specifications'] as List)) {
          if (spec is Map) {
            final key = spec['name'] ?? spec['key'] ?? 'Detail';
            final value = spec['value'] ?? spec['val'] ?? '';
            specWidgets.add(specItem(Icons.label_important_outline_rounded, LocaleProvider.tr(key.toString()), LocaleProvider.tr(value.toString())));
          }
        }
      }
    }

    // Legacy / Hardcoded Specs
    if (p['weight'] != null && p['weight'].toString().isNotEmpty) {
      specWidgets.add(specItem(Icons.scale_rounded, LocaleProvider.tr("Weight"), LocaleProvider.tr(p['weight'].toString())));
    }
    if (p['type'] != null && p['type'].toString().isNotEmpty) {
      specWidgets.add(specItem(Icons.eco_rounded, LocaleProvider.tr("Type"), LocaleProvider.tr(p['type'].toString())));
    }
    if (p['shelf_life'] != null && p['shelf_life'].toString().isNotEmpty) {
      specWidgets.add(specItem(Icons.calendar_month_rounded, LocaleProvider.tr("Shelf Life"), LocaleProvider.tr(p['shelf_life'].toString())));
    }
    if (p['grade'] != null && p['grade'].toString().isNotEmpty) {
      specWidgets.add(specItem(Icons.verified_rounded, LocaleProvider.tr("Grade"), LocaleProvider.tr(p['grade'].toString())));
    }

    // Electronics Specs
    if (p['brand'] != null && p['brand'].toString().isNotEmpty) {
      specWidgets.add(specItem(Icons.branding_watermark_outlined, LocaleProvider.tr("Brand"), LocaleProvider.tr(p['brand'].toString())));
    }
    if (p['warranty'] != null && p['warranty'].toString().isNotEmpty) {
      specWidgets.add(specItem(Icons.security_rounded, LocaleProvider.tr("Warranty"), LocaleProvider.tr(p['warranty'].toString())));
    }
    if (p['display'] != null && p['display'].toString().isNotEmpty) {
      specWidgets.add(specItem(Icons.screenshot_monitor_rounded, LocaleProvider.tr("Display"), LocaleProvider.tr(p['display'].toString())));
    }
    if (p['battery'] != null && p['battery'].toString().isNotEmpty) {
      specWidgets.add(specItem(Icons.battery_charging_full_rounded, LocaleProvider.tr("Battery"), LocaleProvider.tr(p['battery'].toString())));
    }
    if (p['processor'] != null && p['processor'].toString().isNotEmpty) {
      specWidgets.add(specItem(Icons.memory_rounded, LocaleProvider.tr("Processor"), LocaleProvider.tr(p['processor'].toString())));
    }
    if (p['ram'] != null && p['ram'].toString().isNotEmpty) {
      specWidgets.add(specItem(Icons.sd_card_rounded, LocaleProvider.tr("RAM"), LocaleProvider.tr(p['ram'].toString())));
    }

    // Group into rows of 2
    List<Widget> rows = [];
    for (int i = 0; i < specWidgets.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Expanded(child: specWidgets[i]),
              const SizedBox(width: 15),
              Expanded(child: (i + 1 < specWidgets.length) ? specWidgets[i + 1] : const SizedBox()),
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget specItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.dark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
