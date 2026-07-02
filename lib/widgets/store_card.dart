import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../utils/locale_provider.dart';

class StoreCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final VoidCallback onTap;

  const StoreCard({
    super.key,
    required this.shop,
    required this.onTap,
  });

  Future<void> _callStore(BuildContext context) async {
    final phone = (shop["phone"] ?? "").toString().replaceAll(RegExp(r'[^\d+]'), '');
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

  Future<void> _shareStore() async {
    try {
      final name = shop["name"] ?? "Store";
      final owner = shop["owner"] ?? "";
      final phone = shop["phone"] ?? "";
      final address = shop["address"] ?? "";

      final text = "🛒 Check out *$name* on LocalMart!\n\n"
          "👤 Owner: $owner\n"
          "📞 Contact: $phone\n"
          "📍 Address: $address\n\n"
          "Download LocalMart app to browse all products & prices!";

      await Share.share(text);
    } catch (e) {
      debugPrint("❌ Share error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOpen = shop["open"] ?? false;
    final String? logoUrl = shop["logoUrl"]?.toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop Icon or Logo
                Container(
                  height: 65,
                  width: 65,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5EE),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: _buildLogo(logoUrl),
                ),
                const SizedBox(width: 15),
                
                // Shop Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocaleProvider.tr((shop["name"] ?? "Store").toString()),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.dark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        LocaleProvider.tr(shop["category"] ?? "Category"),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.orange, size: 18),
                          const SizedBox(width: 2),
                          Text(
                            (shop["rating"] ?? "0.0").toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          if ((shop["distance"] ?? "").toString().isNotEmpty) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 2),
                            Text(
                              (shop["distance"]).toString(),
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isOpen ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isOpen ? LocaleProvider.tr('open') : LocaleProvider.tr('closed'),
                    style: TextStyle(
                      color: isOpen ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _callStore(context),
                  icon: const Icon(Icons.call_rounded, size: 18, color: AppTheme.primary),
                  label: Text(LocaleProvider.tr('call'), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: const Color(0xFFEAF5EE),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                TextButton.icon(
                  onPressed: _shareStore,
                  icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFFE07A5F)),
                  label: Text(LocaleProvider.tr('share'), style: const TextStyle(color: Color(0xFFE07A5F), fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: const Color(0xFFFFF4EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(String? logoUrl) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.network(
          logoUrl,
          fit: BoxFit.cover,
          width: 65,
          height: 65,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.store_rounded,
              color: AppTheme.primary,
              size: 35,
            );
          },
        ),
      );
    }
    return const Icon(
      Icons.store_rounded,
      color: AppTheme.primary,
      size: 35,
    );
  }
}
