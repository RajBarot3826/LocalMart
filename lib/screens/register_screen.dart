import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_header.dart';
import '../utils/api_handler.dart';
import '../utils/locale_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool agree = false;
  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool isLoading = false;

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (!agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleProvider.tr('accept_terms_error'))),
      );
      return;
    }

    setState(() => isLoading = true);

    final data = {
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'password': passwordController.text,
    };

    final response = await ApiHandler.post('app_register.php', data);

    setState(() => isLoading = false);

    if (response != null && response['status'] == 'success') {
      // Save session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userName', response['user']['name'] ?? nameController.text);
      await prefs.setString('userPhone', response['user']['phone'] ?? phoneController.text);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleProvider.tr('register'))),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response?['message'] ?? LocaleProvider.tr('register'))),
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
              title: LocaleProvider.tr('create_account'),
              subtitle: LocaleProvider.tr('register_subtitle'),
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
                      buildField(LocaleProvider.tr('full_name'), Icons.person, nameController, (value) {
                        if (value == null || value.isEmpty) return LocaleProvider.tr('enter_fullname');
                        return null;
                      }),
                      const SizedBox(height: 15),
                      buildField(LocaleProvider.tr('phone_number'), Icons.phone, phoneController, (value) {
                        if (value == null || value.isEmpty) return LocaleProvider.tr('enter_phone');
                        if (value.length < 10) return LocaleProvider.tr('enter_phone');
                        return null;
                      }, keyboardType: TextInputType.phone),
                      const SizedBox(height: 15),
                      buildField(LocaleProvider.tr('email'), Icons.email, emailController, (value) {
                        if (value == null || value.isEmpty) return LocaleProvider.tr('enter_email');
                        if (!value.contains('@')) return LocaleProvider.tr('enter_email');
                        return null;
                      }, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 15),
                      buildPasswordField(LocaleProvider.tr('password'), hidePassword, passwordController, () {
                        setState(() => hidePassword = !hidePassword);
                      }, (value) {
                        if (value == null || value.isEmpty) return LocaleProvider.tr('enter_password');
                        if (value.length < 6) return LocaleProvider.tr('enter_password');
                        return null;
                      }),
                      const SizedBox(height: 15),
                      buildPasswordField(LocaleProvider.tr('confirm_password'), hideConfirmPassword, confirmPasswordController, () {
                        setState(() => hideConfirmPassword = !hideConfirmPassword);
                      }, (value) {
                        if (value == null || value.isEmpty) return LocaleProvider.tr('confirm_password');
                        if (value != passwordController.text) return LocaleProvider.tr('confirm_password');
                        return null;
                      }),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        value: agree,
                        activeColor: AppTheme.primary,
                        onChanged: (value) => setState(() => agree = value!),
                        title: Text(LocaleProvider.tr('agree_terms'), style: const TextStyle(fontSize: 13)),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          onPressed: isLoading ? null : _registerUser,
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  LocaleProvider.tr('create_account'),
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(LocaleProvider.tr('already_have_account')),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              LocaleProvider.tr('login'),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
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

  Widget buildField(String hint, IconData icon, TextEditingController controller, String? Function(String?) validator, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primary),
        filled: true,
        fillColor: AppTheme.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        errorStyle: const TextStyle(height: 0.8),
      ),
    );
  }

  Widget buildPasswordField(String hint, bool hide, TextEditingController controller, VoidCallback onTap, String? Function(String?) validator) {
    return TextFormField(
      controller: controller,
      obscureText: hide,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock, color: AppTheme.primary),
        suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: onTap),
        filled: true,
        fillColor: AppTheme.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        errorStyle: const TextStyle(height: 0.8),
      ),
    );
  }
}
