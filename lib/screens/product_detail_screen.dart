import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../utils/locale_provider.dart';
import '../widgets/cart_bottom_bar.dart';
import '../widgets/product_quantity_selector.dart';
import '../models/product_model.dart';
import '../utils/api_handler.dart';

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
  int _currentImageIndex = 0;
  List<String> _images = [];

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

    _images = _extractImages();

    _controller.forward();
    
    // Increment real views on backend when product is opened
    String pId = (widget.product['id'] ?? widget.product['product_id'] ?? '').toString();
    if (pId.isNotEmpty) {
      ApiHandler.incrementView('product', pId);
    }
  }

  List<String> _extractImages() {
    final p = widget.product;
    List<String> extracted = [];

    // Check all possible keys that might hold images
    final keysToCheck = ['images', 'images_urls', 'image_url', 'image', 'photos', 'gallery', 'product_images', 'pictures'];

    for (String key in keysToCheck) {
      if (!p.containsKey(key) || p[key] == null) continue;

      final val = p[key];

      if (val is List) {
        for (var item in val) {
          if (item.toString().trim().isNotEmpty) extracted.add(item.toString().trim());
        }
      } else if (val is String && val.trim().isNotEmpty) {
        final strVal = val.trim();
        // Check if it's a JSON array
        if (strVal.startsWith('[') && strVal.endsWith(']')) {
          try {
            final List<dynamic> parsed = jsonDecode(strVal);
            for (var item in parsed) {
              if (item.toString().trim().isNotEmpty) extracted.add(item.toString().trim());
            }
          } catch (_) {
            // Not a valid JSON array, fallback to comma split
            final parts = strVal.split(RegExp(r'[,|;]'));
            for (var part in parts) {
              if (part.trim().isNotEmpty) extracted.add(part.trim());
            }
          }
        } else {
          // Normal comma separated string
          final parts = strVal.split(RegExp(r'[,|;]'));
          for (var part in parts) {
            if (part.trim().isNotEmpty) extracted.add(part.trim());
          }
        }
      }
    }

    // Fallback to imageUrl if everything else is empty
    if (extracted.isEmpty && p['imageUrl'] != null && p['imageUrl'].toString().isNotEmpty) {
      final parts = p['imageUrl'].toString().split(RegExp(r'[,|;]'));
      for (var part in parts) {
        if (part.trim().isNotEmpty) extracted.add(part.trim());
      }
    }
    
    // Deduplicate and return
    return extracted.toSet().toList();
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
        SnackBar(content: Text(LocaleProvider.tr('no_phone_number'))),
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
      bottomNavigationBar: (widget.product["delivery_enabled"] == true || widget.product["delivery_enabled"] == '1' || widget.product["delivery_enabled"] == 1) ? const CartBottomBar() : null,
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
                          backgroundColor: AppTheme.background.withValues(alpha: 0.5),
                        ),
                      ),
                      Positioned(
                        bottom: 40,
                        left: -30,
                        child: CircleAvatar(
                          radius: 80,
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.05),
                        ),
                      ),
                      // Main Product Images
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        padding: const EdgeInsets.only(top: 60, bottom: 30),
                        child: _images.isEmpty
                            ? Hero(
                                tag: 'product_${widget.product["id"] ?? widget.product["name"] ?? "image"}',
                                child: Icon(
                                  widget.product["icon"] as IconData? ?? Icons.shopping_bag_outlined,
                                  size: 180,
                                  color: AppTheme.primary,
                                ),
                              )
                            : Stack(
                                children: [
                                  PageView.builder(
                                    itemCount: _images.length,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentImageIndex = index;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      final baseTag = 'product_${widget.product["id"] ?? widget.product["name"] ?? "image"}';
                                      return Hero(
                                        tag: index == 0 ? baseTag : '${baseTag}_$index',
                                        child: Image.network(
                                          _images[index],
                                          fit: BoxFit.contain,
                                          errorBuilder: (c, e, s) => Icon(
                                            widget.product["icon"] as IconData? ?? Icons.shopping_bag_outlined,
                                            size: 180,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (_images.length > 1)
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(
                                          _images.length,
                                          (index) => AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            margin: const EdgeInsets.symmetric(horizontal: 4),
                                            width: _currentImageIndex == index ? 20 : 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: _currentImageIndex == index ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
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
                          Builder(
                            builder: (context) {
                              final String status = (widget.product["availability"] ?? widget.product["stock_status"] ?? 'In Stock').toString();
                              Color bgColor = Colors.green.shade100;
                              Color textColor = Colors.green;
                              
                              if (status.toLowerCase().contains('out')) {
                                bgColor = Colors.red.shade100;
                                textColor = Colors.red;
                              } else if (status.toLowerCase().contains('pre')) {
                                bgColor = Colors.orange.shade100;
                                textColor = Colors.orange.shade800;
                              }
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  LocaleProvider.tr(status),
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              );
                            }
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
                          const SizedBox(height: 15),
                          if (widget.product["delivery_enabled"] == true || widget.product["delivery_enabled"] == '1' || widget.product["delivery_enabled"] == 1)
                            SizedBox(
                              width: 150,
                              height: 45,
                              child: ProductQuantitySelector(
                                product: Product(
                                  id: widget.product["id"]?.toString() ?? '',
                                  storeId: (widget.product["store_id"] ?? widget.product["vendor_id"] ?? widget.product["shop_id"] ?? '').toString(),
                                  name: widget.product["name"]?.toString() ?? '',
                                  price: (widget.product["price"] ?? '').toString().replaceAll('₹', '').trim(),
                                  category: widget.product["category"]?.toString() ?? '',
                                  description: widget.product["description"]?.toString() ?? '',
                                  imageUrl: widget.product["imageUrl"]?.toString() ?? '',
                                  icon: widget.product["icon"] is IconData
                                      ? widget.product["icon"] as IconData
                                      : Icons.shopping_bag,
                                  rawData: _buildSafeRawData(),
                                ),
                              ),
                            ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Icon(Icons.storefront, size: 20, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${LocaleProvider.tr('sold_by')} ${LocaleProvider.tr(widget.product["store_name"] ?? widget.product["storename"] ?? widget.product["storeName"] ?? 'unknown_store')}",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if ((widget.product["store_address"] ?? widget.product["storeaddress"] ?? widget.product["storeAddress"]) != null && 
                              (widget.product["store_address"] ?? widget.product["storeaddress"] ?? widget.product["storeAddress"]).toString().isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on, size: 20, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    LocaleProvider.tr((widget.product["store_address"] ?? widget.product["storeaddress"] ?? widget.product["storeAddress"]).toString()),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                                  color: Colors.blue.withValues(alpha: 0.1),
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
                                ? LocaleProvider.tr(widget.product["description"].toString())
                                : LocaleProvider.tr("Get this premium quality product from your nearest local mart. We ensure the freshest stock and competitive pricing for all our local customers."),
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
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
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

  final List<String> ignoreKeys = [
    'id', 'product_id', 'vendor_id', 'store_id', 'shop_id', 'name', 'product_name', 
    'price', 'description', 'image_url', 'imageurl', 'image_path', 'images', 'images_urls', 'imagesurls', 'photos', 'gallery', 'icon', 'icon_url',
    'category', 'store_name', 'storename', 'storeaddress', 'store_address', 'distance', 'rating', 'logo_url', 'created_at', 
    'updated_at', 'specifications', 'status', 'is_active', 'deleted_at', 'phone', 
    'contact', 'email', 'storephone', 'store_phone'
  ];

  bool _hasAnySpecs() {
    final p = widget.product;
    bool hasSpecs = false;
    p.forEach((key, value) {
      if (!ignoreKeys.contains(key.toLowerCase().trim()) && value != null && value.toString().trim().isNotEmpty && value.toString().trim().toLowerCase() != 'null') {
        hasSpecs = true;
      }
    });
    
    if (p.containsKey('specifications') && p['specifications'] != null && p['specifications'].toString().isNotEmpty && p['specifications'] != "[]" && p['specifications'] != "{}") {
      hasSpecs = true;
    }
    
    return hasSpecs;
  }

  Widget buildDynamicSpecs() {
    final p = widget.product;
    List<Widget> specWidgets = [];

    // Dynamic specifications sent from the backend as JSON string
    if (p['specifications'] != null) {
      var specData = p['specifications'];
      
      if (specData is String) {
        try {
          specData = jsonDecode(specData);
        } catch (_) {}
      }

      if (specData is Map) {
        specData.forEach((key, value) {
          specWidgets.add(specItem(Icons.label_important_outline_rounded, LocaleProvider.tr(key.toString()), LocaleProvider.tr(value.toString())));
        });
      } else if (specData is List) {
        for (var spec in specData) {
          if (spec is Map) {
            final key = spec['name'] ?? spec['key'] ?? 'Detail';
            final value = spec['value'] ?? spec['val'] ?? '';
            specWidgets.add(specItem(Icons.label_important_outline_rounded, LocaleProvider.tr(key.toString()), LocaleProvider.tr(value.toString())));
          }
        }
      }
    }

    // Automatically parse and display all extra vendor dashboard fields
    p.forEach((key, value) {
      if (!ignoreKeys.contains(key.toLowerCase().trim()) && value != null && value.toString().trim().isNotEmpty && value.toString().trim().toLowerCase() != 'null') {
        
        // Prepare Title Case Key Name (e.g. "weight_qty" -> "Weight Qty")
        String displayKey = key.toString().replaceAll('_', ' ').replaceAll('-', ' ').trim();
        displayKey = displayKey.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
        
        // Automatically determine an appropriate icon based on the key name
        IconData icon = Icons.label_important_outline_rounded;
        String lowerKey = key.toLowerCase();
        if (lowerKey.contains('weight') || lowerKey.contains('qty') || lowerKey.contains('quantity')) {
          icon = Icons.scale_rounded;
        } else if (lowerKey.contains('type') || lowerKey.contains('category')) {
          icon = Icons.eco_rounded;
        } else if (lowerKey.contains('life') || lowerKey.contains('date') || lowerKey.contains('time')) {
          icon = Icons.calendar_month_rounded;
        } else if (lowerKey.contains('grade') || lowerKey.contains('quality')) {
          icon = Icons.verified_rounded;
        } else if (lowerKey.contains('brand')) {
          icon = Icons.branding_watermark_outlined;
        } else if (lowerKey.contains('warranty')) {
          icon = Icons.security_rounded;
        } else if (lowerKey.contains('display') || lowerKey.contains('screen')) {
          icon = Icons.screenshot_monitor_rounded;
        } else if (lowerKey.contains('battery')) {
          icon = Icons.battery_charging_full_rounded;
        } else if (lowerKey.contains('processor') || lowerKey.contains('cpu')) {
          icon = Icons.memory_rounded;
        } else if (lowerKey.contains('ram') || lowerKey.contains('memory')) {
          icon = Icons.sd_card_rounded;
        }

        specWidgets.add(specItem(icon, LocaleProvider.tr(displayKey), LocaleProvider.tr(value.toString())));
      }
    });

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
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
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

  /// Builds a JSON-safe copy of widget.product by stripping non-serializable
  /// values like IconData so json.encode() won't crash in CartManager._saveCart().
  Map<String, dynamic> _buildSafeRawData() {
    final Map<String, dynamic> safe = {};
    widget.product.forEach((key, value) {
      if (value is IconData) return; // skip non-serializable
      safe[key] = value;
    });
    return safe;
  }
}
