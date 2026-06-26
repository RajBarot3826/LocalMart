import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../theme/app_theme.dart';
import '../screens/product_detail_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'product_quantity_selector.dart';

class TopReachedProductsWidget extends StatelessWidget {
  final List<Product> products;
  final String storeName;
  final String storePhone;
  final String storeAddress;
  final bool showCartButtons;

  const TopReachedProductsWidget({
    super.key,
    required this.products,
    required this.storeName,
    required this.storePhone,
    required this.storeAddress,
    this.showCartButtons = true,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    // Sort products by real views descending
    final sortedProducts = List<Product>.from(products)..sort((a, b) => b.views.compareTo(a.views));
    final topProducts = sortedProducts.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("🔥", style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text(
                    "Top Reached Products",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dark,
                    ),
                  ),
                ],
              ),
              Text(
                "See all",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),

        // Horizontal List
        SizedBox(
          height: 230,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            scrollDirection: Axis.horizontal,
            itemCount: topProducts.length,
            itemBuilder: (context, index) {
              final product = topProducts[index];
              return _buildProductCard(context, product, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, Product product, int index) {
    // Generate soft pastel colors based on index for the top background
    final List<Color> bgColors = [
      const Color(0xFFFFF2E0), // Soft orange
      const Color(0xFFE6F4FB), // Soft blue
      const Color(0xFFF3E5F5), // Soft purple
      const Color(0xFFE8F5E9), // Soft green
      const Color(0xFFFFF8E1), // Soft yellow
    ];
    
    final Color topBgColor = bgColors[index % bgColors.length];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: {
                ...product.rawData,
                "name": product.name,
                "price": "₹${product.price}",
                "imageUrl": product.imageUrl,
                "storeName": storeName,
                "storePhone": storePhone,
                "storeAddress": storeAddress,
              },
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: topBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            // Top Section with Badges and Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // Product Image/Icon (Background)
                  Positioned.fill(
                    child: product.imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            child: Image.network(
                              product.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(child: Icon(product.icon, size: 55, color: AppTheme.primary.withValues(alpha: 0.5))),
                            ),
                          )
                        : Center(child: Icon(product.icon, size: 55, color: AppTheme.primary.withValues(alpha: 0.5))),
                  ),
                  
                  // Badges (Foreground)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "#${index + 1}",
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (index < 2) // Show HOT badge for top 2
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "HOT",
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                       .fadeIn(duration: 800.ms),
                    ),
                ],
              ),
            ),
            
            // Bottom White Card
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.dark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "₹${product.price}",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green.shade700),
                        ),
                        Row(
                          children: [
                            Icon(Icons.visibility, size: 10, color: Colors.grey.shade500),
                            const SizedBox(width: 2),
                            Text(
                              "${product.views >= 1000 ? '${(product.views / 1000).toStringAsFixed(1)}k' : product.views}",
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (showCartButtons)
                      Align(
                        alignment: Alignment.center,
                        child: ProductQuantitySelector(product: product),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
