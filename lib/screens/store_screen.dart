import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/store_card.dart';
import '../models/shop_model.dart';
import '../utils/api_handler.dart';
import '../utils/locale_provider.dart';
import '../widgets/banner_slider.dart';
import 'product_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<Shop> allShops = [];
  List<Shop> filteredShops = [];
  bool isLoading = true;
  bool isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    fetchStores();
  }

  Future<void> fetchStores() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      isOfflineMode = false;
    });

    try {
      final data = await ApiHandler.get('stores.php');

      // Your API returns: {"status":true,"stores":[...]}
      List<dynamic> dataList = [];
      if (data is Map) {
        if (data.containsKey('stores')) {
          dataList = data['stores'] ?? [];
        } else if (data.containsKey('data')) {
          dataList = data['data'] ?? [];
        }
      } else if (data is List) {
        dataList = data;
      }

      // Check if it's offline data
      final offline = dataList.isNotEmpty &&
          dataList.first is Map &&
          (dataList.first['shop_name']?.toString().contains('Offline') == true);

      if (!mounted) return;
      setState(() {
        allShops = dataList.map((json) => Shop.fromJson(json)).toList();
        filteredShops = allShops;
        isLoading = false;
        isOfflineMode = offline;
      });

      debugPrint("📋 Loaded ${allShops.length} stores (offline: $offline)");
    } catch (e) {
      debugPrint("❌ Store Fetch Error: $e");
      // Last resort fallback
      try {
        final offlineData = ApiHandler.getOfflineData('stores.php');
        List<dynamic> offlineList = [];
        if (offlineData is Map && offlineData.containsKey('stores')) {
          offlineList = offlineData['stores'];
        } else if (offlineData is List) {
          offlineList = offlineData;
        }
        if (!mounted) return;
        setState(() {
          allShops = offlineList.map((json) => Shop.fromJson(json)).toList();
          filteredShops = allShops;
          isLoading = false;
          isOfflineMode = true;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          allShops = [];
          filteredShops = [];
          isLoading = false;
          isOfflineMode = true;
        });
      }
    }
  }

  void _filterShops(String query) {
    setState(() {
      filteredShops = allShops
          .where((shop) =>
              shop.name.toLowerCase().contains(query.toLowerCase()) ||
              shop.category.toLowerCase().contains(query.toLowerCase()) ||
              shop.owner.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: fetchStores,
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
          // HEADER
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.dark, AppTheme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(35),
                bottomRight: Radius.circular(35),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    Text(
                      LocaleProvider.tr('all_shops'),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFEAF5EE), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: _filterShops,
                    decoration: InputDecoration(
                      hintText: LocaleProvider.tr('search_stores_hint'),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // OFFLINE MODE BANNER
          if (isOfflineMode && !isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.orange.shade800, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      LocaleProvider.tr('offline_mode'),
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  InkWell(
                    onTap: fetchStores,
                    child: Icon(Icons.refresh_rounded, color: Colors.orange.shade800, size: 20),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // BANNER SLIDER (Top Reached Stores)
          if (!isLoading && allShops.isNotEmpty)
            BannerSlider(
              products: const [], // No products, only stores on this screen
              stores: allShops,
            ),
            
          const SizedBox(height: 5),

          // STORE LIST
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 50.0),
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else if (filteredShops.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store_outlined, size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 15),
                    Text(LocaleProvider.tr('no_stores'), style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: fetchStores,
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                      label: Text(LocaleProvider.tr('retry'), style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: filteredShops.length,
                          itemBuilder: (context, index) {
                            final shop = filteredShops[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: StoreCard(
                                shop: {
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
                                  "latitude": shop.latitude,
                                  "longitude": shop.longitude,
                                },
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductScreen(
                                        shop: {
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
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }
}
