import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/product_model.dart';
import '../utils/api_handler.dart';
import '../utils/locale_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    fetchProducts();
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

      final String currentStoreId = (widget.shop["id"] ?? "").toString();

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
    final phone = (widget.shop["phone"] ?? "").toString().replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No phone number available")),
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
      final name = widget.shop["name"] ?? "Store";
      final owner = widget.shop["owner"] ?? "";
      final phone = widget.shop["phone"] ?? "";
      final address = widget.shop["address"] ?? "";
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
                      backgroundColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Hero(
                          tag: widget.shop["name"] ?? "shop_icon",
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
                                LocaleProvider.tr((widget.shop["name"] ?? LocaleProvider.tr('store')).toString()),
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                LocaleProvider.tr((widget.shop["category"] ?? LocaleProvider.tr('local_shop')).toString()),
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              if ((widget.shop["description"] ?? "").toString().isNotEmpty)
                                Text(
                                  LocaleProvider.tr((widget.shop["description"]).toString()),
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
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                children: [
                  infoItem(Icons.person_rounded, LocaleProvider.tr('owner'), LocaleProvider.tr((widget.shop["owner"] ?? LocaleProvider.tr('owner_placeholder')).toString())),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  InkWell(
                    onTap: _callStore,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.phone_rounded, color: Colors.green.shade700, size: 22),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(LocaleProvider.tr('phone'), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(
                                (widget.shop["phone"] ?? LocaleProvider.tr('na')).toString(),
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                          child: Text(LocaleProvider.tr('call_now').toUpperCase(), style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  infoItem(Icons.location_on_rounded, LocaleProvider.tr('address'), LocaleProvider.tr((widget.shop["address"] ?? LocaleProvider.tr('na')).toString())),
                ],
              ),
            ),
          ),

          // OFFLINE BANNER
          if (isOfflineMode && !isLoading)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.orange.shade800, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(LocaleProvider.tr('offline_mode'),
                          style: TextStyle(color: Colors.orange.shade900, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                    InkWell(onTap: fetchProducts, child: Icon(Icons.refresh_rounded, color: Colors.orange.shade800, size: 20)),
                  ],
                ),
              ),
            ),

          // SEARCH BAR
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  onChanged: _filterBySearch,
                  decoration: InputDecoration(
                    hintText: LocaleProvider.tr('search_items_hint'),
                    prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // CATEGORY FILTER CHIPS
          if (!isLoading && categories.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = cat == selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: FilterChip(
                        label: Text(cat == 'All' ? LocaleProvider.tr('show_all') : cat),
                        selected: isSelected,
                        onSelected: (_) => _filterByCategory(cat),
                        backgroundColor: Colors.white,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.dark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: isSelected ? AppTheme.primary : Colors.grey.shade300),
                      ),
                    );
                  },
                ),
              ),
            ),

          // LIST SECTION TITLE
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(LocaleProvider.tr('price_list'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.dark)),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Text("${filteredProducts.length} ${LocaleProvider.tr('items')}", style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 5),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.sort_rounded, color: AppTheme.dark),
                        tooltip: LocaleProvider.tr('sort_products'),
                        onSelected: (value) {
                          currentSort = value;
                          _applyFilters();
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'Default', child: Text(LocaleProvider.tr('sort_default'))),
                          PopupMenuItem(value: 'Price: Low to High', child: Text(LocaleProvider.tr('sort_low_high'))),
                          PopupMenuItem(value: 'Price: High to Low', child: Text(LocaleProvider.tr('sort_high_low'))),
                          PopupMenuItem(value: 'A-Z', child: Text(LocaleProvider.tr('sort_az'))),
                          PopupMenuItem(value: 'Z-A', child: Text(LocaleProvider.tr('sort_za'))),
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
                                final delay = index * 0.1;
                                final animValue = Curves.easeOut.transform((_controller.value - delay).clamp(0.0, 1.0));
                                return Opacity(
                                  opacity: animValue,
                                  child: Transform.translate(offset: Offset(0, 30 * (1 - animValue)), child: productCard(context, product)),
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
    final logoUrl = widget.shop["logoUrl"]?.toString();
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
                "price": "₹${product.price}",
                "image": product.icon,
                "category": product.category,
                "description": product.description,
                "imageUrl": product.imageUrl,
                "storeName": widget.shop["name"],
                "storePhone": widget.shop["phone"],
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(18)),
                child: _buildProductImage(product),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 15),
              child: Column(
                children: [
                  Text(LocaleProvider.tr(product.name), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.dark)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                    child: Text("₹${product.price}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
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
