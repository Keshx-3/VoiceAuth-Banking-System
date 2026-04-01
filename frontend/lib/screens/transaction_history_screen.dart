// lib/screens/transaction_history_screen.dart
import 'package:flutter/material.dart';
import '../api_service/api_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      final transactions = await BankingApiService().getTransactionHistory();

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load transactions: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown date';
    
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final txDate = DateTime(date.year, date.month, date.day);

      if (txDate == today) {
        return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (txDate == yesterday) {
        return 'Yesterday';
      } else {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        return '${months[date.month - 1]} ${date.day}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transaction History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "No transactions yet",
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Your transaction history will appear here",
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTransactions,
                  child: ListView.separated(
                    itemCount: _transactions.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final trans = _transactions[index];
                      
                      // Parse transaction data from API
                      final amount = (trans['amount'] ?? 0).toDouble();
                      final type = trans['transaction_type'] ?? '';
                      final description = trans['description'] ?? '';
                      final timestamp = trans['timestamp'] ?? trans['created_at'];
                      
                      // Get other user info
                      String displayName = 'Unknown';
                      bool isReceived = type == 'DEPOSIT';
                      
                      if (type == 'TRANSFER') {
                        // Sent transaction: receiver_name has the other person
                        final receiverName = trans['receiver_name']?.toString() ?? '';
                        displayName = receiverName.isNotEmpty && receiverName != 'You'
                            ? receiverName : 'Unknown';
                        isReceived = false;
                      } else if (type == 'RECEIVED') {
                        // Received transaction: sender_name has the other person
                        final senderName = trans['sender_name']?.toString() ?? '';
                        displayName = senderName.isNotEmpty && senderName != 'You'
                            ? senderName : 'Unknown';
                        isReceived = true;
                      } else if (type == 'DEPOSIT') {
                        displayName = trans['sender_name'] ?? 'Bank Deposit';
                        isReceived = true;
                      }
                      
                      final avatarLetter = displayName.isNotEmpty 
                          ? displayName[0].toUpperCase() 
                          : 'U';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo[50],
                          child: Text(
                            avatarLetter,
                            style: TextStyle(color: Colors.indigo[900]),
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatDate(timestamp)),
                            if (description.isNotEmpty)
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        trailing: Text(
                          "${isReceived ? '+' : '-'} ₹${amount.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isReceived ? Colors.green[700] : Colors.black,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}