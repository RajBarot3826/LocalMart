import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/product_model.dart';
import '../models/shop_model.dart';
import '../utils/api_handler.dart';
import '../utils/locale_provider.dart';
import 'product_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  bool isLoading = true;
  List<Product> searchResults = [];
  Map<String, Shop> storesMap = {};

  @override
  void initState() {
    super.initState();
    _searchProducts();
  }

  Future<void> _searchProducts() async {
    try {
      // 1. Fetch all stores
      final storesData = await ApiHandler.get('stores.php');
      List<dynamic> storesList = [];
      if (storesData is Map && storesData.containsKey('stores')) {
        storesList = storesData['stores'] ?? [];
      } else if (storesData is List) {
        storesList = storesData;
      }
      
      final Map<String, Shop> tempStoresMap = {};
      for (var json in storesList) {
        final shop = Shop.fromJson(json);
        tempStoresMap[shop.id.toString()] = shop;
      }

      // 2. Fetch all products
      final productsData = await ApiHandler.get('products.php');
      List<dynamic> productsList = [];
      if (productsData is Map && productsData.containsKey('products')) {
        productsList = productsData['products'] ?? [];
      } else if (productsData is List) {
        productsList = productsData;
      }

      final queryLower = widget.query.toLowerCase();
      final List<Product> results = [];

      for (var json in productsList) {
        final product = Product.fromJson(json);
        if (product.name.toLowerCase().contains(queryLower) ||
            product.description.toLowerCase().contains(queryLower) ||
            product.category.toLowerCase().contains(queryLower)) {
          results.add(product);
        }
      }

      if (!mounted) return;
      setState(() {
        storesMap = tempStoresMap;
        searchResults = results;
        isLoading = false;
      });
      
    } catch (e) {
      debugPrint("❌ Search error: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
        searchResults = [];
      });
    }
  }

  Future<void> _callStore(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    try {
      await launchUrl(Uri.parse('tel:$cleanPhone'));
    } catch (e) {
      debugPrint("❌ Call error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppTheme.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.dark, AppTheme.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              title: Text(
                'Search: "${widget.query}"',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            )
          else if (searchResults.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      '${LocaleProvider.tr('no_products')} "${widget.query}"',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = searchResults[index];
                    final store = storesMap[product.storeId];
                    final storeName = store?.name ?? "Unknown Store";
                    final storePhone = store?.phone ?? "";
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                      child: InkWell(
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
                                  "storeName": storeName,
                                  "storePhone": storePhone,
                                  "storeAddress": store?.address ?? "",
                                },
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: product.imageUrl.isNotEmpty
                                      ? Image.network(
                                          product.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Icon(product.icon, color: AppTheme.primary, size: 40),
                                        )
                                      : Icon(product.icon, color: AppTheme.primary, size: 40),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      LocaleProvider.tr(product.name),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.dark),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "₹${product.price}",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primary),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.storefront, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            LocaleProvider.tr(storeName),
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (storePhone.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.call, color: AppTheme.primary),
                                  onPressed: () => _callStore(storePhone),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: searchResults.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
