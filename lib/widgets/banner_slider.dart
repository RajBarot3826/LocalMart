import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/product_model.dart';
import '../models/shop_model.dart';
import '../theme/app_theme.dart';
import '../screens/product_detail_screen.dart';
import '../screens/product_screen.dart';

class BannerSlider extends StatefulWidget {
  final List<Product> products;
  final List<Shop> stores;

  const BannerSlider({super.key, required this.products, required this.stores});

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  final PageController _pageController = PageController(viewportFraction: 0.93);
  int _currentPage = 0;
  Timer? _timer;
  
  // Mixed list of items to display in banner
  List<dynamic> _bannerItems = [];

  @override
  void initState() {
    super.initState();
    _prepareBanners();
    _startTimer();
  }

  void _prepareBanners() {
    // Sort items by real views descending
    final sortedProducts = List<Product>.from(widget.products)..sort((a, b) => b.views.compareTo(a.views));
    final sortedStores = List<Shop>.from(widget.stores)..sort((a, b) => b.views.compareTo(a.views));

    // Take top 5 highest viewed items
    final topProducts = sortedProducts.take(5).toList();
    final topStores = sortedStores.take(5).toList();
    
    // Mix them (If home screen passes only products, it will only be products. If store screen passes only stores, it will only be stores)
    _bannerItems = [...topProducts, ...topStores];
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_bannerItems.isEmpty) return;
      if (_currentPage < _bannerItems.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerItems.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 195, // Wide cinematic aspect ratio
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: _bannerItems.length,
            itemBuilder: (context, index) {
              final item = _bannerItems[index];
              return _buildBannerItem(item);
            },
          ),
        ),
        const SizedBox(height: 12),
        SmoothPageIndicator(
          controller: _pageController,
          count: _bannerItems.length,
          effect: ExpandingDotsEffect(
            dotHeight: 6,
            dotWidth: 6,
            activeDotColor: AppTheme.primary,
            dotColor: Colors.grey.shade300,
            expansionFactor: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildBannerItem(dynamic item) {
    bool isProduct = item is Product;
    String title = isProduct ? item.name : (item as Shop).name;
    String subtitle = isProduct ? "Top Reached Product 🔥" : "Top Reached Store ⭐";
    String buttonText = isProduct ? "Shop Now" : "Visit Store";
    String imageUrl = isProduct ? item.imageUrl : ((item as Shop).logoUrl ?? '');
    String priceOrCategory = isProduct ? "₹${item.price}" : (item as Shop).category;

    return GestureDetector(
      onTap: () {
        if (isProduct) {
          final Product productItem = item;
          String storeName = "Unknown Store";
          String storeAddress = "";
          String storePhone = "";
          
          try {
            final matchedStore = widget.stores.firstWhere((s) => s.id == productItem.storeId);
            storeName = matchedStore.name;
            storeAddress = matchedStore.address;
            storePhone = matchedStore.phone;
          } catch (_) {}

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProductDetailScreen(product: {
              ...productItem.rawData,
              "name": productItem.name,
              "price": "₹${productItem.price}",
              "imageUrl": productItem.imageUrl,
              "storeName": storeName,
              "storeAddress": storeAddress,
              "storePhone": storePhone,
            })),
          );
        } else {
          final shop = item as Shop;
          final shopMap = {
            "id": shop.id,
            "name": shop.name,
            "category": shop.category,
            "rating": shop.rating,
            "distance": shop.distance,
            "open": shop.isOpen,
            "isOpen": shop.isOpen,
            "owner": shop.owner,
            "phone": shop.phone,
            "address": shop.address,
            "description": shop.description,
            "logoUrl": shop.logoUrl,
            "delivery_enabled": shop.deliveryEnabled,
            "delivery_fee_type": shop.deliveryFeeType,
            "delivery_fee": shop.deliveryFee,
          };
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProductScreen(shop: shopMap)),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(isProduct),
                    )
                  : _buildPlaceholder(isProduct),

              // Dark Gradient Overlay for text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isProduct ? Colors.orange : AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .scaleXY(begin: 1.0, end: 1.05, duration: 800.ms, curve: Curves.easeInOut)
                     .shimmer(duration: 1500.ms, color: Colors.white54),

                    const SizedBox(height: 8),

                    // Title
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.5,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1, end: 0),
                    ),

                    const SizedBox(height: 5),

                    // Price or Category
                    Text(
                      priceOrCategory,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    // Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        buttonText,
                        style: TextStyle(
                          color: isProduct ? Colors.orange.shade800 : AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildPlaceholder(bool isProduct) {
    return Container(
      color: isProduct ? Colors.orange.shade100 : AppTheme.primary.withValues(alpha: 0.1),
      child: Icon(
        isProduct ? Icons.shopping_bag : Icons.store,
        size: 80,
        color: isProduct ? Colors.orange.withValues(alpha: 0.3) : AppTheme.primary.withValues(alpha: 0.3),
      ),
    );
  }
}
