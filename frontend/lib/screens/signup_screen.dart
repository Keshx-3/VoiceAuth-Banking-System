// lib/screens/signup_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api_service/api_service.dart';

import 'voice_auth_screen.dart';

// Design constants matching the reference project
const Color _kMediumBlue = Color(0xFF4285F4);
const Color _kWhite = Color(0xFFF0F4FF);

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ──────────────────────────── Existing logic (UNCHANGED) ────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        // Validate file extension - API only accepts .jpg and .png
        final extension = image.path.toLowerCase().split('.').last;
        if (extension != 'jpg' && extension != 'jpeg' && extension != 'png') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select a JPG or PNG image only'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Call API signup
      await BankingApiService().signup(
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        password: _passwordController.text,
        profilePic: _profileImage,
      );

      // Auto-login after successful signup
      await BankingApiService().login(
        _phoneController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Account created successfully! Please set up voice authentication.'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to Voice Authentication Screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const VoiceAuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        // Debug: Print the actual error
        print('Signup error: $e');

        // Show error message
        String errorMessage = 'Failed to create account. Please try again.';
        final errorStr = e.toString();

        if (errorStr.contains('detail')) {
          // Extract error detail from API
          errorMessage = errorStr.replaceAll('Exception: ', '');
        } else if (errorStr.contains('already exists') ||
            errorStr.contains('duplicate')) {
          errorMessage = 'An account with this phone number already exists';
        } else if (errorStr.contains('SocketException') ||
            errorStr.contains('Connection')) {
          errorMessage =
              'Network error. Please check your internet connection.';
        } else {
          // Show the actual error for debugging
          errorMessage = 'Error: ${errorStr.replaceAll('Exception: ', '')}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
                const SizedBox(height: 20),

                // Back button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios, color: _kMediumBlue),
                ),
                const SizedBox(height: 10),

                // Title
                Center(
                  child: Text(
                    'Create Account',
                    style: TextStyle(
                      color: _kMediumBlue,
                      fontSize: 36.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Profile picture picker
                Center(
                  child: GestureDetector(
                    onTap: _isLoading ? null : _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: _kMediumBlue.withOpacity(0.1),
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : null,
                          child: _profileImage == null
                              ? const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: _kMediumBlue,
                                )
                              : null,
                        ),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: _kMediumBlue,
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: _kWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _profileImage == null
                        ? 'Tap to add profile picture (optional)'
                        : 'Tap to change picture',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Full Name
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Phone Number
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (value.length < 10) {
                      return 'Phone number must be at least 10 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // PIN
                _buildTextField(
                  controller: _passwordController,
                  label: 'PIN',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  helperText: '0-4 digit PIN',
                  suffixIcon: GestureDetector(
                    onTap: () =>
                        setState(() => _obscurePin = !_obscurePin),
                    child: Icon(
                      _obscurePin
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 18,
                      color: _kMediumBlue,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 4) {
                      return 'PIN must be 4 digits number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Confirm PIN
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm PIN',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirmPin,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  suffixIcon: GestureDetector(
                    onTap: () => setState(
                        () => _obscureConfirmPin = !_obscureConfirmPin),
                    child: Icon(
                      _obscureConfirmPin
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 18,
                      color: _kMediumBlue,
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Sign Up button
                _buildPrimaryButton(
                  label: 'Sign Up',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleSignup,
                ),
                const SizedBox(height: 30),
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
    String? helperText,
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
        helperText: helperText,
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
}
