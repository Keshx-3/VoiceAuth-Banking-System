// lib/screens/request_money_screen.dart
import 'package:flutter/material.dart';
import '../api_service/api_service.dart';

class RequestMoneyScreen extends StatefulWidget {
  final String userName;
  final String userPhone;

  const RequestMoneyScreen({
    super.key,
    required this.userName,
    required this.userPhone,
  });

  @override
  State<RequestMoneyScreen> createState() => _RequestMoneyScreenState();
}

class _RequestMoneyScreenState extends State<RequestMoneyScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _parsedAmount {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _processRequest() async {
    final amount = _parsedAmount;
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final response = await BankingApiService().createPaymentRequest(amount, widget.userPhone);

      if (mounted) {
        // Check if the request was flagged by fraud detection
        final double fraudScore = (response['fraud_score'] ?? 0).toDouble();
        final String fraudReason = "⚠️Fraud Detected⚠️";

        if (fraudScore > 2 ) {
          // Show fraud warning dialog
          await _showFraudWarningDialog(fraudScore, fraudReason);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request of ₹${amount.toStringAsFixed(0)} sent to ${widget.userName}'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  /// Shows a warning dialog when a payment request is flagged
  Future<void> _showFraudWarningDialog(double fraudScore, String reason) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF1B1B2F),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber.withAlpha(80), width: 2),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Request Flagged',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your payment request has been flagged by our fraud detection system.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.amber[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(fontSize: 12, color: Colors.amber[400]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'I Understand',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarLetter = widget.userName.isNotEmpty
        ? widget.userName[0].toUpperCase()
        : 'U';
    final amount = _parsedAmount;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with close & menu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 26),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.blue[300],
                    child: Text(
                      avatarLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // "Requesting from" label
                  Text(
                    'Requesting from',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Amount input
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      IntrinsicWidth(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 50),
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            autofocus: true,
                            enabled: !_isProcessing,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w300,
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '0',
                              hintStyle: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w300,
                                color: Colors.black,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Note field

                ],
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    disabledBackgroundColor: Colors.blueAccent,
                  ),
                  onPressed: (amount != null && amount > 0 && !_isProcessing)
                      ? _processRequest
                      : null,
                  child: _isProcessing
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          amount != null && amount > 0
                              ? 'Request ₹${amount.toStringAsFixed(0)}'
                              : 'Request',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
