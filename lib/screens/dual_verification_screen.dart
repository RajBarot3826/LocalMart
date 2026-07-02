import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/api_handler.dart';

class DualVerificationScreen extends StatefulWidget {
  final String email;
  final String phone;
  final Future<void> Function() onResendEmailOtp;
  final Future<void> Function() onResendMobileOtp;

  const DualVerificationScreen({
    super.key,
    required this.email,
    required this.phone,
    required this.onResendEmailOtp,
    required this.onResendMobileOtp,
  });

  @override
  State<DualVerificationScreen> createState() => _DualVerificationScreenState();
}

class _DualVerificationScreenState extends State<DualVerificationScreen> {
  final TextEditingController _emailOtpController = TextEditingController();
  final TextEditingController _mobileOtpController = TextEditingController();
  
  bool _isLoading = false;
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _canResend = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _canResend = true;
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailOtpController.dispose();
    _mobileOtpController.dispose();
    super.dispose();
  }

  Future<void> _verifyAll() async {
    final emailCode = _emailOtpController.text.trim();
    final mobileCode = _mobileOtpController.text.trim();

    if (emailCode.length < 6 || mobileCode.length < 6) {
      setState(() {
        _errorMessage = "Please enter 6-digit codes for both email and mobile verification.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Verify Email OTP
      final emailResponse = await ApiHandler.post('verify_email_otp.php', {
        'email': widget.email,
        'otp': emailCode,
      });

      if (emailResponse == null || emailResponse['status'] != true) {
        throw Exception(emailResponse?['message'] ?? "Incorrect Email Verification Code.");
      }

      // 2. Verify Mobile OTP (Twilio)
      final mobileResponse = await ApiHandler.post('verify_twilio_otp.php', {
        'phone': widget.phone,
        'otp': mobileCode,
      });

      if (mobileResponse == null || mobileResponse['status'] != true) {
        throw Exception(mobileResponse?['message'] ?? "Incorrect Mobile Verification Code.");
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, true); // Verified successfully!
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll("Exception: ", "");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Dual Verification", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.dark,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 15,
                  offset: Offset(0, 5),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.security,
                  size: 64,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Verification Required",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.dark),
                ),
                const SizedBox(height: 8),
                Text(
                  "We have sent verification codes to both your email and mobile number. Please enter them below to complete your registration.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 24),
                
                // Email Verification block
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "📧 Email Code (sent to ${widget.email})",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: "",
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    hintText: "000000",
                    hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 0),
                  ),
                ),
                const SizedBox(height: 20),

                // Mobile Verification block
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "📱 Mobile Code (Use 111111 for testing)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _mobileOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: "",
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    hintText: "000000",
                    hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 0),
                  ),
                ),
                const SizedBox(height: 12),

                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _verifyAll,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Verify & Register",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _canResend ? "Didn't receive codes?" : "Resend codes in $_secondsRemaining s",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    if (_canResend) ...[
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() => _isLoading = true);
                                try {
                                  await widget.onResendEmailOtp();
                                  await widget.onResendMobileOtp();
                                  _startTimer();
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text("Verification codes resent successfully.")),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() {
                                      _errorMessage = "Failed to resend: $e";
                                    });
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                  }
                                }
                              },
                        child: const Text(
                          "Resend All",
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      )
                    ]
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
