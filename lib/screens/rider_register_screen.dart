import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/api_handler.dart';

class RiderRegisterScreen extends StatefulWidget {
  const RiderRegisterScreen({super.key});

  @override
  State<RiderRegisterScreen> createState() => _RiderRegisterScreenState();
}

class _RiderRegisterScreenState extends State<RiderRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController vehicleController = TextEditingController();

  bool isLoading = false;
  bool hidePassword = true;

  Future<void> _registerRider() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    final data = {
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'password': passwordController.text,
      'address': addressController.text.trim(),
      'vehicle_number': vehicleController.text.trim().toUpperCase(),
    };

    final response = await ApiHandler.post('rider_register.php', data);
    setState(() => isLoading = false);

    if (response != null && response['status'] == 'success') {
      String newRiderId = response['rider_id'] ?? '${nameController.text.split(' ')[0].toLowerCase()}@localmart.com';
      _showSuccessScreen(newRiderId);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response?['message'] ?? 'Registration failed. Try again.')),
      );
    }
  }

  void _showSuccessScreen(String riderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Scaffold(
          backgroundColor: AppTheme.primary,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 100, color: Colors.white),
                  const SizedBox(height: 30),
                  const Text(
                    "Registration Successful!",
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "You are now a LocalMart Delivery Partner. Your unique login ID is:",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        riderId,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.dark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Please remember it, because without this you cannot login.",
                            style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text("Go to Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.dark),
        title: const Text("Partner Registration", style: TextStyle(color: AppTheme.dark, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Join the Fleet 🛵", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.primary)),
              const SizedBox(height: 5),
              Text("Deliver with LocalMart and earn on your own schedule.", style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 30),
              
              _buildField(nameController, "Full Name", Icons.person),
              _buildField(phoneController, "Phone Number", Icons.phone, type: TextInputType.phone),
              _buildField(emailController, "Email Address", Icons.email, type: TextInputType.emailAddress),
              _buildPasswordField(),
              _buildField(addressController, "Current Address", Icons.location_on),
              _buildField(vehicleController, "Vehicle Number (e.g. GJ-01-AB-1234)", Icons.motorcycle),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: isLoading ? null : _registerRider,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Register as Partner", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primary),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
        validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
      ),
    );
  }

  Widget _buildPasswordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: passwordController,
        obscureText: hidePassword,
        decoration: InputDecoration(
          hintText: "Password",
          prefixIcon: const Icon(Icons.lock, color: AppTheme.primary),
          suffixIcon: IconButton(
            icon: Icon(hidePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
            onPressed: () => setState(() => hidePassword = !hidePassword),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
        validator: (v) => (v == null || v.length < 6) ? "Min 6 characters" : null,
      ),
    );
  }
}
