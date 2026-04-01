// lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'login_screen.dart';
import '../api_service/api_service.dart';
import '../widgets/shimmer_loading.dart';
import '../models/user.dart';
import 'transaction_passbook_screen.dart';

class ProfileScreen extends StatefulWidget {
  final void Function(int)? onTabSwitch;

  const ProfileScreen({super.key, this.onTabSwitch});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isVoiceAuthEnabled = false;
  bool _isVoiceAuthLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch user details from API
      final userData = await BankingApiService().getUserDetails();
      final user = User.fromJson(userData);

      // Fetch voice-auth status
      bool voiceAuthStatus = false;
      try {
        voiceAuthStatus = await BankingApiService().getVoiceAuthStatus();
      } catch (_) {
        // Default to false if we can't fetch status
      }

      setState(() {
        _currentUser = user;
        _nameController.text = user.fullName;
        _phoneController.text = user.phoneNumber;
        _isVoiceAuthEnabled = voiceAuthStatus;
        _isLoading = false;
      });
    } on AuthenticationException {
      // Handle authentication errors - redirect to login
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleVoiceAuth() async {
    setState(() => _isVoiceAuthLoading = true);
    try {
      final newStatus = await BankingApiService().toggleVoiceAuth();
      if (mounted) {
        setState(() {
          _isVoiceAuthEnabled = newStatus;
          _isVoiceAuthLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Voice authentication enabled'
                  : 'Voice authentication disabled',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthenticationException {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVoiceAuthLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle voice auth: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddFundsDialog() async {
    final TextEditingController amountController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Funds'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  try {
                    // Call API deposit
                    await BankingApiService().deposit(amount);

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '₹${amount.toStringAsFixed(2)} added successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );

                      // Reload user data to get updated balance
                      await _loadUserData();
                    }
                  } on AuthenticationException {
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to add funds: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await BankingApiService().logout();
      if (mounted) {
        // Navigate back to login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _changeProfilePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        // Show loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading profile picture...')),
          );
        }

        // Upload to API
        await BankingApiService().changeProfilePic(File(image.path));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Reload user data
          await _loadUserData();
        }
      }
    } on AuthenticationException {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Profile picture upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile picture: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4FF),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.3)),
            ),
            child: const Icon(Icons.arrow_back, color: Color(0xFF4285F4), size: 18),
          ),
          onPressed: () {
            if (widget.onTabSwitch != null) {
              widget.onTabSwitch!(0); // Switch to Home tab
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          "My Profile",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.3)),
              ),
              child: const Icon(Icons.logout, color: Color(0xFF4285F4), size: 18),
            ),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const ProfileShimmer()
          : _currentUser == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Failed to load profile'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // Profile Picture
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue[50],
                                border: Border.all(
                                  color: const Color(0xFF4285F4).withOpacity(0.2),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _currentUser!.profilePicUrl != null
                                    ? Image.network(
                                        _currentUser!.profilePicUrl!,
                                        fit: BoxFit.cover,
                                        width: 120,
                                        height: 120,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                              strokeWidth: 2,
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Text(
                                              _currentUser!.fullName.isNotEmpty
                                                  ? _currentUser!.fullName
                                                      .substring(0, 1)
                                                      .toUpperCase()
                                                  : "U",
                                              style: TextStyle(
                                                fontSize: 48,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[800],
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Center(
                                        child: Text(
                                          _currentUser!.fullName.isNotEmpty
                                              ? _currentUser!.fullName
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : "U",
                                          style: TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[800],
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: _changeProfilePicture,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4285F4),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // User Name
                        Text(
                          _currentUser!.fullName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Phone Number
                        Text(
                          _currentUser!.phoneNumber,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF4285F4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Balance Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A73E8), Color(0xFF6C5CE7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1A73E8).withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "TOTAL BALANCE",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "₹${_formatBalance(_currentUser!.balance)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: _showAddFundsDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Text(
                                    'Add Funds',
                                    style: TextStyle(
                                      color: Color(0xFF1A73E8),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Section Header
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Security & Payments',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Voice Authentication Row
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4285F4).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.mic,
                                  color: Color(0xFF4285F4),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Voice Authentication',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Secure access via voice',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _isVoiceAuthLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Switch(
                                      value: _isVoiceAuthEnabled,
                                      activeColor: const Color(0xFF4285F4),
                                      onChanged: (value) => _toggleVoiceAuth(),
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Payment History Row
                        GestureDetector(
                          onTap: () {
                            if (widget.onTabSwitch != null) {
                              widget.onTabSwitch!(1); // Switch to History tab
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TransactionPassbookScreen(),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.history,
                                    color: Colors.orange[700],
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Payment History',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'View all past transactions',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }

  /// Format balance with commas for readability
  String _formatBalance(double balance) {
    final parts = balance.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    
    // Indian number formatting
    if (intPart.length <= 3) return '$intPart.$decPart';
    
    String result = intPart.substring(intPart.length - 3);
    int remaining = intPart.length - 3;
    int i = 0;
    while (remaining > 0) {
      final chunk = remaining >= 2 ? 2 : remaining;
      result = '${intPart.substring(remaining - chunk, remaining)},$result';
      remaining -= chunk;
      i++;
    }
    return '$result.$decPart';
  }
}