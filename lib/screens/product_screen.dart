import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/product_model.dart';
import '../models/shop_model.dart';
import '../utils/api_handler.dart';
import '../utils/locale_provider.dart';
import '../widgets/top_reached_products.dart';
import '../widgets/product_quantity_selector.dart';
import '../widgets/cart_bottom_bar.dart';
import '../utils/cart_manager.dart';
import 'product_detail_screen.dart';

class ProductScreen extends StatefulWidget {
  final Map<String, dynamic> shop;

  const ProductScreen({super.key, required this.shop});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  bool isLoading = true;
  bool isOfflineMode = false;
  String selectedCategory = 'All';
  String searchQuery = '';
  String currentSort = 'Default';
  List<String> categories = ['All'];
  late Map<String, dynamic> shopData;

  bool get deliveryEnabled => shopData["delivery_enabled"] == true || shopData["delivery_enabled"] == 1;

  @override
  void initState() {
    super.initState();
    shopData = Map<String, dynamic>.from(widget.shop);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Set store info in CartManager for delivery tracking
    if (deliveryEnabled) {
      CartManager().setStoreInfo(
        storeId: (shopData["id"] ?? "").toString(),
        storeName: shopData["name"]?.toString() ?? 'Store',
        storeAddress: (shopData["address"] ?? "").toString(),
        deliveryEnabled: true,
        deliveryFeeType: (shopData["delivery_fee_type"] ?? 'free').toString(),
        deliveryFee: double.tryParse(shopData["delivery_fee"]?.toString() ?? '0') ?? 0.0,
        latitude: double.tryParse(shopData["latitude"]?.toString() ?? ''),
        longitude: double.tryParse(shopData["longitude"]?.toString() ?? ''),
      );
    }

    // Increment view count when store is opened (centralized)
    final String currentStoreId = (shopData["id"] ?? "").toString();
    if (currentStoreId.isNotEmpty) {
      ApiHandler.incrementView('store', currentStoreId);
    }

    fetchProducts();
    fetchLatestStoreInfo();
  }

  Future<void> fetchLatestStoreInfo() async {
    try {
      final String currentStoreId = (shopData["id"] ?? "").toString();
      if (currentStoreId.isEmpty) return;

      final data = await ApiHandler.get('stores.php');
      List<dynamic> dataList = [];
      if (data is Map && data.containsKey('stores')) {
        dataList = data['stores'] ?? [];
      } else if (data is List) {
        dataList = data;
      }

      final List<Shop> shops = dataList.map((json) => Shop.fromJson(json)).toList();
      Shop? matchedShop;
      for (final s in shops) {
        if (s.id.toString() == currentStoreId) {
          matchedShop = s;
          break;
        }
      }

      if (matchedShop != null && mounted) {
        setState(() {
          shopData = {
            "id": matchedShop!.id,
            "name": matchedShop.name,
            "category": matchedShop.category,
            "rating": matchedShop.rating,
            "distance": matchedShop.distance,
            "open": matchedShop.isOpen,
            "owner": matchedShop.owner,
            "phone": matchedShop.phone,
            "address": matchedShop.address,
            "description": matchedShop.description,
            "logoUrl": matchedShop.logoUrl,
            "delivery_enabled": matchedShop.deliveryEnabled,
            "delivery_fee_type": matchedShop.deliveryFeeType,
            "delivery_fee": matchedShop.deliveryFee,
            "latitude": matchedShop.latitude,
            "longitude": matchedShop.longitude,
          };
          
          // Update CartManager with latest info
          if (deliveryEnabled) {
            CartManager().setStoreInfo(
              storeId: matchedShop.id,
              storeName: matchedShop.name,
              storeAddress: matchedShop.address,
              deliveryEnabled: true,
              deliveryFeeType: matchedShop.deliveryFeeType,
              deliveryFee: matchedShop.deliveryFee,
              latitude: matchedShop.latitude,
              longitude: matchedShop.longitude,
            );
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Failed to fetch latest store details: $e");
    }
  }

  Future<void> fetchProducts() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      isOfflineMode = false;
    });

    try {
      final data = await ApiHandler.get('products.php');

      List<dynamic> dataList = [];
      if (data is Map && data.containsKey('products')) {
        dataList = data['products'] ?? [];
      } else if (data is List) {
        dataList = data;
      }

      final offline = dataList.isNotEmpty &&
          dataList.first is Map &&
          (dataList.first['name']?.toString().contains('Offline') == true);

      final String currentStoreId = (shopData["id"] ?? "").toString();

      final products = dataList
          .map((json) => Product.fromJson(json))
          .where((p) => p.storeId == currentStoreId || currentStoreId.isEmpty)
          .toList();

      // Extract unique categories
      final cats = <String>{'All'};
      for (final p in products) {
        if (p.category.isNotEmpty) cats.add(p.category);
      }

      if (!mounted) return;
      setState(() {
        allProducts = products;
        filteredProducts = products;
        categories = cats.toList();
        isLoading = false;
        isOfflineMode = offline;
        _controller.forward();
      });

      debugPrint("📦 Loaded ${allProducts.length} products for store $currentStoreId");
    } catch (e) {
      debugPrint("❌ Product Fetch Error: $e");
      if (!mounted) return;
      setState(() {
        allProducts = [];
        filteredProducts = [];
        isLoading = false;
        isOfflineMode = true;
        _controller.forward();
      });
    }
  }

  void _applyFilters() {
    setState(() {
      filteredProducts = allProducts.where((p) {
        final matchesCategory = selectedCategory == 'All' || p.category == selectedCategory;
        final matchesSearch = searchQuery.isEmpty || 
            p.name.toLowerCase().contains(searchQuery.toLowerCase()) || 
            p.description.toLowerCase().contains(searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();

      if (currentSort == 'Price: Low to High') {
        filteredProducts.sort((a, b) => double.parse(a.price.replaceAll(',', '')).compareTo(double.parse(b.price.replaceAll(',', ''))));
      } else if (currentSort == 'Price: High to Low') {
        filteredProducts.sort((a, b) => double.parse(b.price.replaceAll(',', '')).compareTo(double.parse(a.price.replaceAll(',', ''))));
      } else if (currentSort == 'A-Z') {
        filteredProducts.sort((a, b) => a.name.compareTo(b.name));
      } else if (currentSort == 'Z-A') {
        filteredProducts.sort((a, b) => b.name.compareTo(a.name));
      }
    });
  }

  void _filterByCategory(String category) {
    selectedCategory = category;
    _applyFilters();
  }

  void _filterBySearch(String query) {
    searchQuery = query;
    _applyFilters();
  }

  Future<void> _callStore() async {
    final phone = (shopData["phone"] ?? "").toString().replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleProvider.tr('no_phone_number'))),
        );
      }
      return;
    }
    try {
      await launchUrl(Uri.parse('tel:$phone'));
    } catch (e) {
      debugPrint("❌ Call error: $e");
    }
  }

  Future<void> _shareStore() async {
    try {
      final name = shopData["name"] ?? "Store";
      final owner = shopData["owner"] ?? "";
      final phone = shopData["phone"] ?? "";
      final address = shopData["address"] ?? "";
      final itemCount = allProducts.length;

      final text = "🛒 Check out *$name* on LocalMart!\n\n"
          "👤 Owner: $owner\n"
          "📞 Contact: $phone\n"
          "📍 Address: $address\n"
          "📦 Products: $itemCount items available\n\n"
          "Download LocalMart app to browse all products & prices!";

      await Share.share(text);
    } catch (e) {
      debugPrint("❌ Share error: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: deliveryEnabled ? const CartBottomBar() : null,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // HEADER
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.dark,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.call_rounded, color: Colors.white),
                onPressed: _callStore,
                tooltip: "Call Store",
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: _shareStore,
                tooltip: "Share Store",
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.dark, AppTheme.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -10,
                    right: -20,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'shop_${shopData["id"] ?? shopData["name"] ?? "icon"}',
                          child: Container(
                            height: 70,
                            width: 70,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                              ],
                            ),
                            child: _buildShopIcon(),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocaleProvider.tr((shopData["name"] ?? LocaleProvider.tr('store')).toString()),
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                LocaleProvider.tr((shopData["category"] ?? LocaleProvider.tr('local_shop')).toString()),
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              if ((shopData["description"] ?? "").toString().isNotEmpty)
                                Text(
                                  LocaleProvider.tr((shopData["description"]).toString()),
                                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // SHOP INFO CARD with Call & Share buttons
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  infoItem(Icons.person_rounded, LocaleProvider.tr('owner'), LocaleProvider.tr((shopData["owner"] ?? LocaleProvider.tr('owner_placeholder')).toString())),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                  InkWell(
                    onTap: _callStore,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.phone_rounded, color: Colors.green.shade700, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(LocaleProvider.tr('phone'), style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(
                                (shopData["phone"] ?? LocaleProvider.tr('na')).toString(),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text(LocaleProvider.tr('call_now').toUpperCase(), style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                  infoItem(Icons.location_on_rounded, LocaleProvider.tr('address'), LocaleProvider.tr((shopData["address"] ?? LocaleProvider.tr('na')).toString())),
                ],
              ),
            ),
          ),

          // OFFLINE BANNER
          if (isOfflineMode && !isLoading)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 15),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.orange.shade800, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(LocaleProvider.tr('offline_mode'),
                          style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                    InkWell(onTap: fetchProducts, child: Icon(Icons.refresh_rounded, color: Colors.orange.shade800, size: 18)),
                  ],
                ),
              ),
            ),

          // TOP REACHED PRODUCTS
          if (!isLoading && filteredProducts.isNotEmpty)
            SliverToBoxAdapter(
              child: TopReachedProductsWidget(
                products: filteredProducts,
                storeName: shopData["name"] ?? "Unknown Store",
                storePhone: shopData["phone"] ?? "",
                storeAddress: shopData["address"] ?? "",
                showCartButtons: deliveryEnabled,
              ),
            ),

          // SEARCH BAR
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  onChanged: _filterBySearch,
                  decoration: InputDecoration(
                    hintText: LocaleProvider.tr('search_items_hint'),
                    prefixIcon: Icon(Icons.search, color: AppTheme.primary, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          // CATEGORY FILTER CHIPS
          if (!isLoading && categories.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = cat == selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat == 'All' ? LocaleProvider.tr('show_all') : LocaleProvider.tr(cat)),
                        selected: isSelected,
                        onSelected: (_) => _filterByCategory(cat),
                        backgroundColor: Colors.white,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.dark,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: isSelected ? AppTheme.primary : Colors.grey.shade300),
                      ),
                    );
                  },
                ),
              ),
            ),

          // LIST SECTION TITLE
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(LocaleProvider.tr('price_list'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.dark)),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text("${filteredProducts.length} ${LocaleProvider.tr('items')}", style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 5),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.sort_rounded, color: AppTheme.dark, size: 20),
                        tooltip: LocaleProvider.tr('sort_products'),
                        onSelected: (value) {
                          currentSort = value;
                          _applyFilters();
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'Default', child: Text(LocaleProvider.tr('sort_default'), style: const TextStyle(fontSize: 13))),
                          PopupMenuItem(value: 'Price: Low to High', child: Text(LocaleProvider.tr('sort_low_high'), style: const TextStyle(fontSize: 13))),
                          PopupMenuItem(value: 'Price: High to Low', child: Text(LocaleProvider.tr('sort_high_low'), style: const TextStyle(fontSize: 13))),
                          PopupMenuItem(value: 'A-Z', child: Text(LocaleProvider.tr('sort_az'), style: const TextStyle(fontSize: 13))),
                          PopupMenuItem(value: 'Z-A', child: Text(LocaleProvider.tr('sort_za'), style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // PRODUCT GRID
          isLoading
              ? const SliverToBoxAdapter(
                  child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppTheme.primary))))
              : filteredProducts.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 15),
                            Text(
                              selectedCategory == 'All' ? LocaleProvider.tr('no_products') : "No '$selectedCategory' products",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton.icon(
                              onPressed: () => _filterByCategory('All'),
                              icon: const Icon(Icons.clear_all, color: Colors.white, size: 18),
                              label: Text(LocaleProvider.tr('show_all'), style: const TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = filteredProducts[index];
                            return AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                // Cap the delay so all items fully animate
                                // Max 0.5s total stagger, so even 20+ items look clean
                                final delay = (index * 0.05).clamp(0.0, 0.5);
                                final animValue = Curves.easeOut.transform(
                                  ((_controller.value - delay) / (1.0 - delay)).clamp(0.0, 1.0),
                                );
                                return Opacity(
                                  opacity: animValue,
                                  child: Transform.translate(offset: Offset(0, 20 * (1 - animValue)), child: productCard(context, product)),
                                );
                              },
                            );
                          },
                          childCount: filteredProducts.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildShopIcon() {
    final logoUrl = shopData["logoUrl"]?.toString();
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(logoUrl, fit: BoxFit.cover,
            errorBuilder: (c, e, s) => const Icon(Icons.storefront_rounded, color: AppTheme.primary, size: 35)),
      );
    }
    return const Icon(Icons.storefront_rounded, color: AppTheme.primary, size: 35);
  }

  Widget infoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.dark), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget productCard(BuildContext context, Product product) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: {
                ...product.rawData,
                "name": product.name,
                "price": product.price, // ensure price doesn't get double ₹ symbols
                "icon": product.icon,
                "category": product.category,
                "description": product.description,
                "imageUrl": product.imageUrl,
                "storeName": shopData["name"],
                "storePhone": shopData["phone"],
                "storeAddress": shopData["address"],
              },
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEAF5EE), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFEAF5EE), borderRadius: BorderRadius.circular(18)),
                child: _buildProductImage(product),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 15),
              child: Column(
                children: [
                  Text(LocaleProvider.tr(product.name), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.dark)),
                  const SizedBox(height: 5),
                  Text("₹${product.price}", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (deliveryEnabled) ProductQuantitySelector(product: product),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product) {
    if (product.imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          product.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Icon(product.icon, size: 45, color: AppTheme.primary),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                color: AppTheme.primary,
                strokeWidth: 2,
              ),
            );
          },
        ),
      );
    }
    return Icon(product.icon, size: 45, color: AppTheme.primary);
  }
}
