import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/cart_manager.dart';
import '../utils/address_manager.dart';
import '../utils/locale_provider.dart';
import '../utils/app_translations.dart';
import 'my_orders_screen.dart';
import '../widgets/connection_error_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isLoading = false;
  String errorMessage = "";
  Map<String, dynamic>? userData;
  bool notificationsOn = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('userName') ?? "Raj Kumar";
      final phone = prefs.getString('userPhone') ?? "+91 98765 43210";
      notificationsOn = prefs.getBool('notificationsOn') ?? true;

      setState(() {
        userData = {
          "name": name,
          "phone": phone,
        };
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Connection error. Make sure your phone has internet and the website is up.";
      });
    }
  }

  // ═══════════════════════════════════════════════════
  // EDIT PROFILE DIALOG
  // ═══════════════════════════════════════════════════
  void _showEditProfile() {
    final nameController = TextEditingController(text: userData?["name"] ?? "");
    final phoneController = TextEditingController(text: userData?["phone"] ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(LocaleProvider.tr('edit_profile'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: LocaleProvider.tr('your_name'),
                prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: LocaleProvider.tr('phone_number'),
                prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocaleProvider.tr('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('userName', nameController.text.trim());
              await prefs.setString('userPhone', phoneController.text.trim());
              if (!mounted) return;
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadProfile();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(LocaleProvider.tr('profile_updated')),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Text(LocaleProvider.tr('save'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // LANGUAGE PICKER BOTTOM SHEET
  // ═══════════════════════════════════════════════════
  void _showLanguagePicker() {
    final currentLocale = LocaleProvider.instance.locale;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              height: 4,
              width: 40,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    LocaleProvider.tr('select_language'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.dark),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: AppTranslations.supportedLanguages.length,
                itemBuilder: (listCtx, index) {
                  final entry = AppTranslations.supportedLanguages.entries.elementAt(index);
                  final code = entry.key;
                  final name = entry.value;
                  final isSelected = code == currentLocale;

                  return ListTile(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await LocaleProvider.instance.setLocale(code);
                      if (!mounted) return;
                      // Navigate to home and clear stack so all screens rebuild fresh
                      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(LocaleProvider.tr('language_changed')),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    leading: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          code.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.dark,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 18,
                        color: isSelected ? AppTheme.primary : AppTheme.dark,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 26)
                        : const Icon(Icons.circle_outlined, color: Colors.grey, size: 22),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // VISIT HISTORY
  // ═══════════════════════════════════════════════════
  void _showVisitHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('visitHistory') ?? [];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              height: 4,
              width: 40,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppTheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        LocaleProvider.tr('visit_history'),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.dark),
                      ),
                    ],
                  ),
                  if (historyJson.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await prefs.remove('visitHistory');
                        if (!mounted) return;
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(LocaleProvider.tr('history_cleared')),
                            backgroundColor: AppTheme.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Text(LocaleProvider.tr('clear_history'), style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: historyJson.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store_outlined, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 15),
                          Text(LocaleProvider.tr('no_history'), style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          const SizedBox(height: 5),
                          Text(LocaleProvider.tr('visit_history_desc'), style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: historyJson.length,
                      itemBuilder: (context, index) {
                        try {
                          final store = jsonDecode(historyJson[historyJson.length - 1 - index]);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 45,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.store, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(store['name'] ?? 'Store', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text(store['category'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        } catch (_) {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // NOTIFICATIONS TOGGLE
  // ═══════════════════════════════════════════════════
  void _toggleNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationsOn = !notificationsOn;
    });
    await prefs.setBool('notificationsOn', notificationsOn);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notificationsOn ? LocaleProvider.tr('notifications_on') : LocaleProvider.tr('notifications_off')),
        backgroundColor: notificationsOn ? AppTheme.primary : Colors.grey,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ABOUT DIALOG
  // ═══════════════════════════════════════════════════
  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.storefront, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(width: 12),
            const Text("LocalMart", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(LocaleProvider.tr('version'), style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 15),
            Text(LocaleProvider.tr('about_text'), style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocaleProvider.tr('ok'), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PRIVACY POLICY
  // ═══════════════════════════════════════════════════
  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              height: 4,
              width: 40,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.policy_rounded, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    LocaleProvider.tr('privacy_policy'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.dark),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Text(
                  LocaleProvider.tr('privacy_text'),
                  style: const TextStyle(fontSize: 15, height: 1.8, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // COMING SOON DIALOG
  // ═══════════════════════════════════════════════════
  void _showComingSoon() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(LocaleProvider.tr('coming_soon'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(LocaleProvider.tr('coming_soon_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocaleProvider.tr('ok'), style: const TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : errorMessage.isNotEmpty
              ? SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios, color: AppTheme.dark),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ConnectionErrorWidget(
                          errorMessage: errorMessage,
                          onRetry: _loadProfile,
                        ),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 200,
                      pinned: true,
                      backgroundColor: AppTheme.dark,
                      leading: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              const CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.person, size: 50, color: AppTheme.primary),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                userData?["name"] ?? "Raj Kumar",
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                userData?["phone"] ?? "+91 98765 43210",
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ──── ACCOUNT SETTINGS ────
                            Text(LocaleProvider.tr('account_settings'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.dark)),
                            const SizedBox(height: 15),
                            settingsTile(
                              Icons.edit_rounded,
                              LocaleProvider.tr('edit_profile'),
                              LocaleProvider.tr('update_details'),
                              onTap: _showEditProfile,
                            ),
                            settingsTile(
                              Icons.shopping_bag_rounded,
                              'My Orders',
                              'Track and view previous orders',
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
                              },
                            ),
                            settingsTile(
                              Icons.location_on_rounded,
                              LocaleProvider.tr('my_addresses'),
                              LocaleProvider.tr('manage_addresses'),
                              onTap: _showComingSoon,
                            ),
                            settingsTile(
                              Icons.history_rounded,
                              LocaleProvider.tr('visit_history'),
                              LocaleProvider.tr('recently_viewed'),
                              onTap: _showVisitHistory,
                            ),

                            const SizedBox(height: 25),

                            // ──── PREFERENCES ────
                            Text(LocaleProvider.tr('preferences'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.dark)),
                            const SizedBox(height: 15),
                            settingsTile(
                              notificationsOn ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                              LocaleProvider.tr('notifications'),
                              notificationsOn ? LocaleProvider.tr('notifications_on') : LocaleProvider.tr('notifications_off'),
                              onTap: _toggleNotifications,
                              trailing: Switch(
                                value: notificationsOn,
                                onChanged: (_) => _toggleNotifications(),
                                activeThumbColor: AppTheme.primary,
                              ),
                            ),
                            settingsTile(
                              Icons.language_rounded,
                              LocaleProvider.tr('app_language'),
                              LocaleProvider.instance.currentLanguageName,
                              onTap: _showLanguagePicker,
                            ),

                            const SizedBox(height: 25),

                            // ──── APP INFO ────
                            Text(LocaleProvider.tr('app_info'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.dark)),
                            const SizedBox(height: 15),
                            settingsTile(
                              Icons.info_outline_rounded,
                              LocaleProvider.tr('about'),
                              LocaleProvider.tr('version'),
                              onTap: _showAbout,
                            ),
                            settingsTile(
                              Icons.policy_rounded,
                              LocaleProvider.tr('privacy_policy'),
                              LocaleProvider.tr('privacy_desc'),
                              onTap: _showPrivacyPolicy,
                            ),

                            const SizedBox(height: 30),

                            // ──── LOGOUT ────
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.remove('isLoggedIn');
                                  await prefs.remove('userId');
                                  await prefs.remove('userName');
                                  await prefs.remove('userPhone');
                                  await prefs.remove('userEmail');
                                  await prefs.remove('userRole');
                                  CartManager().clearCart();
                                  AddressManager().clearMemory();
                                  if (!context.mounted) return;
                                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                                },
                                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                                label: Text(LocaleProvider.tr('logout'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget settingsTile(IconData icon, String title, String subtitle, {VoidCallback? onTap, Widget? trailing}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppTheme.primary, size: 24),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
