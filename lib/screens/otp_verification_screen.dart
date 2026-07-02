import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/api_handler.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String? email;
  final String? phone;
  final Future<void> Function() onResendOtp; // Callback to trigger a resend

  const OtpVerificationScreen({
    super.key,
    this.email,
    this.phone,
    required this.onResendOtp,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  String _otpValue = "";
  bool _isLoading = false;
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _canResend = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Auto-focus on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNode.requestFocus();
    });
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
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final code = _otpValue.trim();
    if (code.length < 6) {
      setState(() {
        _errorMessage = "Please enter all 6 digits of the OTP code.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String targetType = widget.phone != null ? 'phone' : 'email';
    final String targetValue = widget.phone ?? widget.email ?? '';
    final String apiEndpoint = widget.phone != null ? 'verify_twilio_otp.php' : 'verify_email_otp.php';

    try {
      final response = await ApiHandler.post(apiEndpoint, {
        targetType: targetValue,
        'otp': code,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        if (response != null && response['status'] == true) {
          Navigator.pop(context, true); // Return true indicating successful verification
        } else {
          setState(() {
            _errorMessage = response?['message'] ?? "Invalid OTP code. Please try again.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Verification failed: $e";
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onResendOtp();
      setState(() {
        _isLoading = false;
        _otpController.clear();
        _otpValue = "";
      });
      _startTimer();
      _otpFocusNode.requestFocus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.phone != null 
                ? "OTP verification code resent to your phone." 
                : "OTP verification code resent to your email."), 
            backgroundColor: Colors.green
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to resend code: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.phone != null ? "Phone Verification" : "Email Verification", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.phone != null ? Icons.sms_outlined : Icons.mark_email_read_outlined, color: AppTheme.primary, size: 60),
              ),
              const SizedBox(height: 24),
              const Text(
                "Enter Verification Code",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.dark),
              ),
              const SizedBox(height: 10),
              Text(
                widget.phone != null
                    ? "We have sent a 6-digit OTP code to\n${widget.phone}\n(Use 111111 for testing)"
                    : "We have sent a 6-digit OTP code to\n${widget.email}",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 30),
              
              // Hidden-text field design for perfectly aligned OTP boxes
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0,
                    child: SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _otpController,
                        focusNode: _otpFocusNode,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(counterText: ""),
                        onChanged: (val) {
                          setState(() {
                            _otpValue = val;
                          });
                          if (val.length == 6) {
                            _verifyOtp(); // Auto-submit when fully entered
                          }
                        },
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      String char = "";
                      if (_otpValue.length > index) {
                        char = _otpValue[index];
                      }
                      
                      bool isFocused = _otpValue.length == index && _otpFocusNode.hasFocus;
                      
                      return GestureDetector(
                        onTap: () {
                          _otpFocusNode.requestFocus();
                        },
                        child: Container(
                          width: 44,
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFocused ? AppTheme.primary : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            char,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.dark),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _verifyOtp,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Verify & Proceed",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 25),
              
              // Countdown & Resend Code
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _canResend ? "Didn't receive code? " : "Resend code in ",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  _canResend
                      ? TextButton(
                          onPressed: _isLoading ? null : _resendCode,
                          child: const Text(
                            "Resend OTP",
                            style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                          ),
                        )
                      : Text(
                          "$_secondsRemaining seconds",
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
