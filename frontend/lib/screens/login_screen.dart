// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'signup_screen.dart';
import '../widgets/main_container.dart';

import '../api_service/api_service.dart';

// Design constants matching the reference project
const Color _kMediumBlue = Color(0xFF4285F4);
const Color _kWhite = Color(0xFFF0F4FF);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ──────────────────────────── Existing logic (UNCHANGED) ────────────────────
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Call API login - username is phone number, password is the PIN/password
      await BankingApiService().login(
        _phoneController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        // Navigate directly to MainContainer (Dashboard)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainContainer()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        // Show error message
        String errorMessage = 'Login failed. Please try again.';
        if (e.toString().contains('detail')) {
          // Extract error detail from API
          errorMessage = e.toString().replaceAll('Exception: ', '');
        } else if (e.toString().contains('credentials')) {
          errorMessage = 'Invalid phone number or PIN';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _kWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 150),

                // Title
                Center(
                  child: Text(
                    'Login',
                    style: TextStyle(
                      color: _kMediumBlue,
                      fontSize: 40.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Enter your details to login',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14.0,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Phone Number field
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      value!.isEmpty ? 'Enter phone number' : null,
                ),
                const SizedBox(height: 10.0),

                // PIN field
                _buildTextField(
                  controller: _passwordController,
                  label: 'PIN',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscurePin = !_obscurePin),
                    child: Icon(
                      _obscurePin ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: _kMediumBlue,
                    ),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter PIN' : null,
                ),
                const SizedBox(height: 10.0),

                // Forgot PIN link
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Forgot PIN?',
                    style: TextStyle(
                      color: _kMediumBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),

                // Login button
                _buildPrimaryButton(
                  label: 'Login',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleLogin,
                ),
                const SizedBox(height: 10.0),

                // Sign Up button (bordered style)
                _buildSecondaryButton(
                  label: "Don't have an account? Sign Up",
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────── Styled input field matching the reference design ──────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    int? maxLength,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLength: maxLength,
      enabled: !_isLoading,
      cursorColor: _kMediumBlue,
      style: const TextStyle(color: _kMediumBlue, fontSize: 14.0),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        labelStyle: const TextStyle(color: _kMediumBlue),
        focusColor: _kMediumBlue,
        filled: true,
        fillColor: Colors.grey.shade100,
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kMediumBlue),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        prefixIcon: Icon(icon, size: 18, color: _kMediumBlue),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }

  // ─────────── Primary (filled) button ───────────────────────────────────────
  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: _kMediumBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: SizedBox(
            height: 60.0,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_kWhite),
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: _kWhite,
                        fontWeight: FontWeight.w600,
                        fontSize: 16.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────── Secondary (bordered) button ───────────────────────────────────
  Widget _buildSecondaryButton({
    required String label,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kMediumBlue, width: 1.0),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: SizedBox(
            height: 60.0,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: _kMediumBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 16.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
