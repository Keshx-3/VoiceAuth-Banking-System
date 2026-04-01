// lib/screens/send_money_screen.dart
import 'package:flutter/material.dart';
import '../api_service/api_service.dart';
import '../widgets/voice_verification_dialog.dart';
import '../widgets/payment_success_screen.dart';

class SendMoneyScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  final double? initialAmount;

  // Accepting arguments via constructor
  const SendMoneyScreen({
    super.key,
    required this.userName,
    required this.userPhone,
    this.initialAmount,
  });

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  Future<void> _processPayment() async {
    // Validate amount
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    // Check voice-auth toggle status
    bool verified = false;
    try {
      final isVoiceAuthEnabled = await BankingApiService().getVoiceAuthStatus();

      if (isVoiceAuthEnabled) {
        if (!mounted) return;
        final voiceOk = await showVoiceVerificationDialog(context);
        if (!voiceOk) {
          if (mounted) _showError('Voice verification failed. Payment cancelled.');
          return;
        }
        if (!mounted) return;
        verified = await showPinVerificationDialog(context, amount: amount);
      } else {
        if (mounted) {
          verified = await showPinVerificationDialog(context, amount: amount);
        }
      }
    } catch (e) {
      if (mounted) {
        verified = await showPinVerificationDialog(context, amount: amount);
      }
    }

    if (!verified) {
      if (mounted) {
        _showError('Authentication failed. Payment cancelled.');
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Call API transfer — if flag_score > 0, _processResponse throws ProbableFraudException
      final response = await BankingApiService().transfer(
        widget.userPhone,
        amount,
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        // Check if the transfer was flagged by the fraud detection system (200 with FLAGGED status)
        final msgField = response['message'];
        if (msgField is Map) {
          final message = (msgField['message'] ?? '').toString().toUpperCase();
          if (message == 'PROBABLE_FRAUD') {
            throw ProbableFraudException(
              explanation: msgField['explanation'] ?? 'Suspicious transaction detected',
              fraudScore: (msgField['fraud_score'] as num?)?.toInt() ?? 0,
            );
          }
        }

        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentSuccessScreen(
                amount: amount,
                recipientName: widget.userName,
                recipientPhone: widget.userPhone,
              ),
            ),
          );
          if (mounted) {
            Navigator.pop(context, true);
          }
        }
      }
    } on ProbableFraudException catch (e) {
      // 403 with PROBABLE_FRAUD — show warning with Continue / Go Back
      if (mounted) {
        setState(() => _isProcessing = false);
        final confirmed = await _showFraudWarningDialog(amount, e.explanation, e.fraudScore);
        if (confirmed && mounted) {
          // User chose to continue — re-call transfer with confirm_fraud: true
          setState(() => _isProcessing = true);
          try {
            await BankingApiService().transfer(
              widget.userPhone,
              amount,
              description: _descriptionController.text.trim(),
              confirmFraud: true,
            );
            if (mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentSuccessScreen(
                    amount: amount,
                    recipientName: widget.userName,
                    recipientPhone: widget.userPhone,
                  ),
                ),
              );
              if (mounted) {
                Navigator.pop(context, true);
              }
            }
          } catch (retryError) {
            if (mounted) {
              setState(() => _isProcessing = false);
              _showError('Payment failed: ${retryError.toString().replaceAll('Exception: ', '')}');
            }
          }
        }
      }
    } on AccountSuspendedException catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showAccountSuspendedDialog(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);

        String errorMessage = 'Payment failed. Please try again.';
        final errorStr = e.toString();

        if (errorStr.contains('Insufficient balance') ||
            errorStr.contains('insufficient')) {
          errorMessage = 'Insufficient balance. Please add funds.';
        } else if (errorStr.contains('detail')) {
          errorMessage = errorStr.replaceAll('Exception: ', '');
        }

        _showError(errorMessage);
      }
    }
  }

  /// Shows a warning dialog when a transfer is flagged as suspicious (post-success)
  Future<void> _showFlaggedTransactionDialog(double amount) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Transaction Flagged',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your transfer of ₹${amount.toStringAsFixed(0)} has been flagged for review by our fraud detection system.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'I Understand',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a fraud warning dialog with Continue / Go Back buttons
  /// Returns true if the user wants to continue, false to go back
  Future<bool> _showFraudWarningDialog(double amount, String explanation, int fraudScore) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withAlpha(80), width: 2),
                ),
                child: const Icon(
                  Icons.gpp_maybe_rounded,
                  color: Colors.redAccent,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Suspicious Transaction',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                explanation,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              // Fraud score indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fraud Score: $fraudScore — Continuing may flag your account.',
                        style: TextStyle(fontSize: 12, color: Colors.red[800], fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Continue button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Continue Anyway',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Go back button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[800],
                    side: BorderSide(color: Colors.grey[400]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  /// Shows a full-screen dialog when the account is suspended
  void _showAccountSuspendedDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog.fullscreen(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xB9C0FFFF), Color(0xFF585FD8)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Shield icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(30),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red.withAlpha(60), width: 3),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.redAccent,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Account Suspended',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your account has been suspended due to multiple flagged transactions. You cannot send money until your account is reviewed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  const SizedBox(height: 16),
                  // Go back button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.red.withAlpha(30), // Light red background
                        foregroundColor: Colors.red[900],          // Dark red text
                        side: BorderSide(color: Colors.red.withAlpha(100)), // Light red border
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx); // Close dialog
                        Navigator.pop(context); // Go back from send screen
                      },
                      child: const Text(
                        'Go Back',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        appBar: AppBar(
          leading: _isProcessing
              ? const SizedBox.shrink()
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Paying ${widget.userName}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                widget.userPhone,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            const Spacer(),
            Center(
              child: IntrinsicWidth(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  enabled: !_isProcessing,
                  style: const TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    prefixText: " ₹ ",
                    border: InputBorder.none,
                    hintText: "0",
                  ),
                ),
              ),
            ),

            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                  ),
                  onPressed: _isProcessing ? null : _processPayment,
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Pay", style: TextStyle(fontSize: 18)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward)
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
}
