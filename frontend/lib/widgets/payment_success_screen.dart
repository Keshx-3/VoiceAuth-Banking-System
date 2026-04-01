import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final double amount;
  final String recipientName;
  final String recipientPhone;

  const PaymentSuccessScreen({
    super.key,
    required this.amount,
    required this.recipientName,
    required this.recipientPhone,
  });

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      final intPart = amount.toStringAsFixed(0);
      if (intPart.length <= 3) return '$intPart.00';
      final lastThree = intPart.substring(intPart.length - 3);
      String remaining = intPart.substring(0, intPart.length - 3);
      final buffer = StringBuffer();
      while (remaining.length > 2) {
        buffer.write(remaining.substring(0, remaining.length - 2));
        buffer.write(',');
        remaining = remaining.substring(remaining.length - 2);
      }
      buffer.write(remaining);
      buffer.write(',');
      buffer.write(lastThree);
      return '${buffer.toString()}.00';
    }
    return amount.toStringAsFixed(2);
  }

  String _formatDateTime() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');
    return '${months[now.month - 1]} ${now.day}, ${now.year} • ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFEEF4FF),
        body: Column(
          children: [
            // --- Header ---
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 40,
              ),
              child: Column(
                children: [
                  // Back button + title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context, true),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.black87,
                            size: 24,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Payment Status',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Lottie animation
                  Lottie.asset(
                    'assets/animations/payment_success.json',
                    width: 250,
                    height: 250,
                    repeat: false,
                  ),
                  const SizedBox(height: 0),

                  // Amount
                  Text(
                    '₹${_formatAmount(amount)}',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Payment Successful text
                  Text(
                    'Payment Successful',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // --- All Details in Single Card ---
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Paid To
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF4285F4).withOpacity(0.15),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF4285F4),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PAID TO',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              recipientName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Date & Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Date & Time',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        Text(
                          _formatDateTime(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Payment Mode
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Payment Mode',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet,
                                size: 18, color: Colors.blue[600]),
                            const SizedBox(width: 6),
                            const Text(
                              'Wallet Balance',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Divider(color: Colors.grey[200], thickness: 1),
                    const SizedBox(height: 16),

                    // Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Completed',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Recipient Phone
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recipient Phone',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        Text(
                          recipientPhone,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Transaction Type
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transaction Type',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const Text(
                          'Money Transfer',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Trust icons
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user, size: 20, color: Colors.grey[400]),
                  const SizedBox(width: 16),
                  Icon(Icons.shield, size: 20, color: Colors.grey[400]),
                  const SizedBox(width: 16),
                  Icon(Icons.lock, size: 20, color: Colors.grey[400]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
