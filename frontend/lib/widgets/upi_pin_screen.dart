import 'package:flutter/material.dart';
import '../api_service/api_service.dart';

/// Full-screen UPI-style PIN entry screen
/// Returns true if PIN verification succeeds, false otherwise
class UpiPinScreen extends StatefulWidget {
  final String? accountInfo;
  final double? amount;

  const UpiPinScreen({
    super.key,
    this.accountInfo,
    this.amount,
  });

  @override
  State<UpiPinScreen> createState() => _UpiPinScreenState();
}

class _UpiPinScreenState extends State<UpiPinScreen> {
  final List<String> _pin = [];
  final int _pinLength = 4;
  bool _isVerifying = false;
  bool _showPin = false;
  String? _error;

  void _onKeyPressed(String key) {
    if (_isVerifying) return;
    if (_pin.length < _pinLength) {
      setState(() {
        _pin.add(key);
        _error = null;
      });
    }
  }

  void _onBackspace() {
    if (_isVerifying) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _pin.removeLast();
        _error = null;
      });
    }
  }

  Future<void> _onSubmit() async {
    if (_pin.length < _pinLength) {
      setState(() => _error = 'Enter complete PIN');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      await BankingApiService().verifyPin(_pin.join());
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _pin.clear();
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FF),
      body: SafeArea(
        child: Column(
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, color: Color(0xFF1A237E), size: 24),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Payment Authorization',
                      style: TextStyle(
                        color: Color(0xFF1A237E),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // UPI-style badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'UPI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),



            const Spacer(flex: 1),

            // --- PIN Entry Section ---
            Column(
              children: [
                // Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'ENTER UPI PIN',
                      style: TextStyle(
                        color: Color(0xFF1A237E),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => setState(() => _showPin = !_showPin),
                      child: Row(
                        children: [
                          Icon(
                            _showPin ? Icons.visibility : Icons.visibility_off,
                            color: const Color(0xFF5C6BC0),
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showPin ? 'HIDE' : 'SHOW',
                            style: const TextStyle(
                              color: Color(0xFF5C6BC0),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // PIN dots/digits
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    final bool filled = index < _pin.length;
                    return Container(
                      width: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 32,
                            child: Center(
                              child: filled
                                  ? _showPin
                                      ? Text(
                                          _pin[index],
                                          style: const TextStyle(
                                            color: Color(0xFF1A237E),
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : Container(
                                          width: 14,
                                          height: 14,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF1A237E),
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          Container(
                            height: 2,
                            color: filled ? const Color(0xFF1A237E) : const Color(0xFFB0BEC5),
                          ),
                        ],
                      ),
                    );
                  }),
                ),

                // Error message
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400.withAlpha(50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const Spacer(flex: 1),

            // --- Custom Numeric Keypad ---
            Container(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
              child: Column(
                children: [
                  _buildKeyRow(['1', '2', '3']),
                  const SizedBox(height: 12),
                  _buildKeyRow(['4', '5', '6']),
                  const SizedBox(height: 12),
                  _buildKeyRow(['7', '8', '9']),
                  const SizedBox(height: 12),
                  // Last row: backspace, 0, submit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKeyButton(
                        child: const Icon(Icons.backspace_outlined, color: Color(0xFF1A237E), size: 24),
                        onTap: _onBackspace,
                      ),
                      _buildKeyButton(
                        child: const Text('0', style: TextStyle(color: Color(0xFF1A237E), fontSize: 28, fontWeight: FontWeight.w400)),
                        onTap: () => _onKeyPressed('0'),
                      ),
                      // Submit button
                      GestureDetector(
                        onTap: _isVerifying ? null : _onSubmit,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1A237E),
                            border: Border.all(color: const Color(0xFF283593), width: 2),
                          ),
                          child: Center(
                            child: _isVerifying
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.check, color: Colors.white, size: 32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- Bottom branding ---
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SECURED BY ',
                    style: TextStyle(
                      color: const Color(0xFF1A237E).withAlpha(120),
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withAlpha(30),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'UPI',
                      style: TextStyle(
                        color: const Color(0xFF1A237E).withAlpha(200),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        return _buildKeyButton(
          child: Text(
            key,
            style: const TextStyle(
              color: Color(0xFF1A237E),
              fontSize: 28,
              fontWeight: FontWeight.w400,
            ),
          ),
          onTap: () => _onKeyPressed(key),
        );
      }).toList(),
    );
  }

  Widget _buildKeyButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A237E).withAlpha(15),
        ),
        child: Center(child: child),
      ),
    );
  }
}
