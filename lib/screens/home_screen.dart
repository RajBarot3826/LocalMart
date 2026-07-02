import 'package:flutter/material.dart';
import '../utils/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/store_card.dart';
import '../models/shop_model.dart';
import '../models/product_model.dart';
import '../utils/api_handler.dart';
import 'store_screen.dart';
import 'product_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';
import 'search_results_screen.dart';
import '../utils/address_manager.dart';
import '../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Shop> featuredShops = [];
  List<Product> topProducts = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String userName = "Guest";

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchFeaturedStores();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    await AddressManager().init();
    setState(() {
      userName = prefs.getString('userName') ?? "Guest";
    });
    // Ask for location permission with a dialog before starting tracking
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final hasPerm = await LocationService().requestPermissionWithPrompt(context);
        if (hasPerm) {
          LocationService().startTracking();
        }
      }
    });
  }

  Future<void> _fetchFeaturedStores() async {
    try {
      // 1. Fetch stores
      final storesData = await ApiHandler.get('stores.php');
      List<dynamic> storesList = [];
      if (storesData is Map && storesData.containsKey('stores')) {
        storesList = storesData['stores'] ?? [];
      } else if (storesData is List) {
        storesList = storesData;
      }

      // 2. Fetch products to find the stores with highest products
      final productsData = await ApiHandler.get('products.php');
      List<dynamic> productsList = [];
      if (productsData is Map && productsData.containsKey('products')) {
        productsList = productsData['products'] ?? [];
      } else if (productsData is List) {
        productsList = productsData;
      }

      // 3. Count products per store
      final Map<String, int> productCounts = {};
      for (var p in productsList) {
        if (p is Map) {
          final storeId = p['store_id']?.toString() ?? '';
          productCounts[storeId] = (productCounts[storeId] ?? 0) + 1;
        }
      }

      // 4. Parse stores and sort by product count descending
      final List<Shop> parsedStores = [];
      for (var json in storesList) {
        if (json is Map) {
          try {
            parsedStores.add(Shop.fromJson(Map<String, dynamic>.from(json)));
          } catch (_) {}
        }
      }
      
      parsedStores.sort((a, b) {
        final countA = productCounts[a.id.toString()] ?? 0;
        final countB = productCounts[b.id.toString()] ?? 0;
        return countB.compareTo(countA); // Descending
      });

      // 5. Parse Top Products
      final List<Product> parsedProducts = [];
      for (var json in productsList) {
        if (json is Map) {
          try {
            parsedProducts.add(Product.fromJson(Map<String, dynamic>.from(json)));
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        featuredShops = parsedStores.take(2).toList();
        topProducts = parsedProducts.take(10).toList();
        isLoading = false;
      });

      debugPrint("🏠 Home: Loaded ${featuredShops.length} featured stores");
    } catch (e) {
      debugPrint("❌ Home fetch error: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onSearchSubmit(String query) {
    if (query.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(query: query.trim()),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _fetchFeaturedStores,
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
            // HEADER
            Container(
              height: 380,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.dark, AppTheme.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -20,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: -30,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  Positioned(
                    top: 50,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 35),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                    ),
                  ),
                  SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 85,
                            width: 85,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 5))
                              ],
                            ),
                            child: const Icon(Icons.storefront, size: 45, color: AppTheme.primary),
                          ),
                          const SizedBox(height: 15),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              "${LocaleProvider.tr('welcome')} ${userName.split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}' : '').join(' ')} 👋",
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            LocaleProvider.tr('discover_stores'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 25),
                          
                          // SEARCH BAR
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              height: 55,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                onSubmitted: _onSearchSubmit,
                                decoration: InputDecoration(
                                  hintText: LocaleProvider.tr('search_products_hint'),
                                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                                  prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.primary),
                                    onPressed: () => _onSearchSubmit(_searchController.text),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -40),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 20)
                  ],
                ),
                child: Column(
                  children: [
                    // QUICK ACTIONS
                    Row(
                      children: [
                        Expanded(
                          child: actionButton(
                            context,
                            LocaleProvider.tr('scan_qr'),
                            Icons.qr_code_scanner_rounded,
                            const Color(0xFFEAF5EE),
                            const Color(0xFF2E6F40),
                            Border.all(color: const Color(0xFFD4EDDA), width: 1.5),
                            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QrScannerScreen())),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: actionButton(
                            context,
                            LocaleProvider.tr('all_shops'),
                            Icons.store_rounded,
                            const Color(0xFFFFF4EB),
                            const Color(0xFFE07A5F),
                            Border.all(color: const Color(0xFFFFE3D1), width: 1.5),
                            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StoreScreen())),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        LocaleProvider.tr('featured_stores'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.dark),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // FEATURED STORES — from real API
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      )
                    else if (featuredShops.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.store_outlined, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(LocaleProvider.tr('no_stores'), style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _fetchFeaturedStores,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(LocaleProvider.tr('retry')),
                            ),
                          ],
                        ),
                      )
                    else
                      ...featuredShops.map((shop) {
                        final shopMap = {
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
                        };

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: StoreCard(
                            shop: shopMap,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductScreen(shop: shopMap),
                                ),
                              );
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget actionButton(BuildContext context, String title, IconData icon, Color bgColor, Color textColor, BoxBorder border, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: bgColor,
          border: border,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: textColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 34),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
