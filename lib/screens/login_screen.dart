import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_header.dart';
import '../utils/api_handler.dart';
import '../utils/cart_manager.dart';
import '../utils/address_manager.dart';
import '../utils/locale_provider.dart';
import 'register_screen.dart';
import 'rider_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;
  String selectedRole = 'customer';

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final data = {
      'phone': phoneController.text.trim(),
      'email': phoneController.text.trim(),
      'password': passwordController.text,
      'role': selectedRole,
    };

    final response = await ApiHandler.post('app_login.php', data);

    setState(() => isLoading = false);

    if (response != null && response['status'] == 'success') {
      // Save session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      // Save user ID for rider API calls
      final userId = response['user']['id'];
      if (userId != null) {
        await prefs.setInt('userId', userId is int ? userId : int.tryParse(userId.toString()) ?? 0);
      }
      await prefs.setString('userName', response['user']['name'] ?? 'User');
      await prefs.setString('userPhone', response['user']['phone'] ?? phoneController.text);
      await prefs.setString('userEmail', phoneController.text);
      String role = response['role'] ?? 'customer';
      await prefs.setString('userRole', role);
      if (role == 'rider') {
        await prefs.setString('vehicleNumber', response['user']['vehicle_number'] ?? '');
        await prefs.setBool('isRiderOnline', false); // Start offline!
        // Ensure backend knows they are offline
        try {
          await ApiHandler.post('toggle_rider_status.php', {
            'rider_id': userId.toString(),
            'status': 'offline',
          });
        } catch (e) {
          debugPrint("Failed to set rider offline on login: $e");
        }
      }
      
      final userPhone = response['user']['phone'] ?? phoneController.text;
      await AddressManager().loadForUser(userPhone);

      CartManager().clearCart();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleProvider.tr('login'))),
      );

      if (role == 'rider') {
        Navigator.pushReplacementNamed(context, '/rider_main');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response?['message'] ?? LocaleProvider.tr('login'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            AnimatedHeader(
              title: LocaleProvider.tr('welcome'),
              subtitle: LocaleProvider.tr('login_subtitle'),
            ),
            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                    )
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Role Selector Slider
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => selectedRole = 'customer'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: selectedRole == 'customer' ? AppTheme.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: selectedRole == 'customer'
                                        ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "Customer",
                                    style: TextStyle(
                                      color: selectedRole == 'customer' ? Colors.white : Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => selectedRole = 'rider'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: selectedRole == 'rider' ? AppTheme.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: selectedRole == 'rider'
                                        ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "Delivery Rider",
                                    style: TextStyle(
                                      color: selectedRole == 'rider' ? Colors.white : Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: selectedRole == 'customer' ? TextInputType.phone : TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: selectedRole == 'customer'
                              ? LocaleProvider.tr('phone_number')
                              : "Rider ID",
                          prefixIcon: Icon(
                            selectedRole == 'customer' ? Icons.phone : Icons.person,
                            color: AppTheme.primary,
                          ),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          errorStyle: const TextStyle(height: 0.8),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return selectedRole == 'customer'
                                ? LocaleProvider.tr('enter_phone')
                                : "Please enter your Rider ID";
                          }
                          if (selectedRole == 'customer' && value.length < 10) {
                            return LocaleProvider.tr('enter_phone');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: passwordController,
                        obscureText: hidePassword,
                        decoration: InputDecoration(
                          hintText: LocaleProvider.tr('password'),
                          prefixIcon: const Icon(Icons.lock, color: AppTheme.primary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              hidePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                hidePassword = !hidePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          errorStyle: const TextStyle(height: 0.8),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return LocaleProvider.tr('enter_password');
                          }
                          if (value.length < 6) {
                            return LocaleProvider.tr('enter_password');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(LocaleProvider.tr('coming_soon'))),
                            );
                          },
                          child: Text(LocaleProvider.tr('forgot_password')),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          onPressed: isLoading ? null : _loginUser,
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  LocaleProvider.tr('login'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(LocaleProvider.tr('or'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: socialButton(Icons.g_mobiledata, "Google")),
                          const SizedBox(width: 10),
                          Expanded(child: socialButton(Icons.facebook, "Facebook")),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(LocaleProvider.tr('dont_have_account')),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterScreen()),
                              );
                            },
                            child: Text(
                              LocaleProvider.tr('register'),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RiderRegisterScreen()),
                              );
                            },
                            child: const Text(
                              "Become a Delivery Partner",
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget socialButton(IconData icon, String title) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.dark),
          const SizedBox(width: 5),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
