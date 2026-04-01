// lib/screens/transaction_passbook_screen.dart
import 'package:flutter/material.dart';
import '../api_service/api_service.dart';
import '../models/user.dart';
import '../widgets/shimmer_loading.dart';

class TransactionPassbookScreen extends StatefulWidget {
  final void Function(int)? onTabSwitch;

  const TransactionPassbookScreen({super.key, this.onTabSwitch});

  @override
  State<TransactionPassbookScreen> createState() =>
      TransactionPassbookScreenState();
}

class TransactionPassbookScreenState extends State<TransactionPassbookScreen> {
  List<dynamic> _transactions = [];
  User? _currentUser;
  bool _isLoading = true;
  String _filterType = 'All'; // All, Sent, Received
  // Map of contact name/id → full profile pic URL
  Map<String, String> _contactProfilePics = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Public method to refresh data from outside (e.g. tab switch)
  void refreshData() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch user details, transaction history, and contacts in parallel
      final results = await Future.wait([
        BankingApiService().getUserDetails(),
        BankingApiService().getTransactionHistory(),
        BankingApiService().getRecentContacts(),
      ]);

      final userDetails = results[0] as Map<String, dynamic>;
      final transactions = results[1] as List<dynamic>;
      final contacts = results[2] as List<dynamic>;

      // Build profile pic lookup map from contacts
      final Map<String, String> picMap = {};
      for (final contact in contacts) {
        final name = contact['full_name']?.toString() ?? '';
        final id = contact['id']?.toString() ?? '';
        final rawPic = contact['profile_pic']?.toString();

        if (rawPic != null && rawPic.isNotEmpty) {
          String fullUrl;
          if (rawPic.startsWith('http://') || rawPic.startsWith('https://')) {
            fullUrl = rawPic;
          } else if (rawPic.startsWith('/')) {
            fullUrl = '${BankingApiService.baseUrl}$rawPic';
          } else {
            fullUrl = '${BankingApiService.baseUrl}/$rawPic';
          }
          if (name.isNotEmpty) picMap[name] = fullUrl;
          if (id.isNotEmpty) picMap[id] = fullUrl;
        }
      }

      setState(() {
        _currentUser = User.fromJson(userDetails);
        _transactions = transactions;
        _contactProfilePics = picMap;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<dynamic> get _filteredTransactions {
    if (_filterType == 'All') {
      return _transactions;
    } else if (_filterType == 'Sent') {
      return _transactions.where((trans) {
        final type = trans['transaction_type'] ?? '';
        return type == 'TRANSFER';
      }).toList();
    } else {
      // Received
      return _transactions.where((trans) {
        final type = trans['transaction_type'] ?? '';
        return type == 'DEPOSIT' || type == 'RECEIVED';
      }).toList();
    }
  }

  double get _totalSent {
    return _transactions.fold(0.0, (sum, trans) {
      final type = trans['transaction_type'] ?? '';
      final amount = (trans['amount'] ?? 0).toDouble();
      if (type == 'TRANSFER') {
        return sum + amount;
      }
      return sum;
    });
  }

  double get _totalReceived {
    return _transactions.fold(0.0, (sum, trans) {
      final type = trans['transaction_type'] ?? '';
      final amount = (trans['amount'] ?? 0).toDouble();
      if (type == 'DEPOSIT' || type == 'RECEIVED') {
        return sum + amount;
      }
      return sum;
    });
  }

  String _formatBalance(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    if (intPart.length <= 3) return '₹$intPart.$decPart';
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
    return '₹$buffer.$decPart';
  }

  String _formatAmount(double amount) {
    final intPart = amount.toStringAsFixed(0);
    if (intPart.length <= 3) return '₹ $intPart';
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
    return '₹ $buffer';
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $amPm';
    } catch (e) {
      return dateStr;
    }
  }

  String _getMonthYearKey(String? dateStr) {
    if (dateStr == null) return 'UNKNOWN';
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    try {
      final date = DateTime.parse(dateStr);
      return '${months[date.month - 1]} ${date.year}';
    } catch (_) {
      try {
        final parts = dateStr.split(' ')[0].split('-');
        if (parts.length == 3) {
          final month = int.parse(parts[1]);
          final year = parts[2];
          return '${months[month - 1]} $year';
        }
      } catch (_) {}
      return 'UNKNOWN';
    }
  }

  /// Groups the filtered transactions by month-year and returns an ordered
  /// list of widgets with headers interleaved.
  List<Widget> _buildGroupedTransactionList() {
    final transactions = _filteredTransactions;
    final List<Widget> widgets = [];
    String? currentGroup;

    for (int i = 0; i < transactions.length; i++) {
      final trans = transactions[i];
      final timestamp = trans['timestamp'] ?? trans['created_at'];
      final group = _getMonthYearKey(timestamp);

      if (group != currentGroup) {
        currentGroup = group;
        // Add spacing before second+ headers
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 24));
        }
        widgets.add(_buildMonthYearHeader(group));
        widgets.add(const SizedBox(height: 12));
      } else {
        widgets.add(const SizedBox(height: 12));
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildTransactionCard(trans),
        ),
      );
    }

    return widgets;
  }

  Widget _buildMonthYearHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('All Transactions'),
                trailing: _filterType == 'All' 
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _filterType = 'All');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward, color: Colors.red),
                title: const Text('Sent Only'),
                trailing: _filterType == 'Sent' 
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _filterType = 'Sent');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward, color: Colors.green),
                title: const Text('Received Only'),
                trailing: _filterType == 'Received' 
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _filterType = 'Received');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddFundsDialog() {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Money'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
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
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                try {
                  await BankingApiService().deposit(amount);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Funds added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add funds: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Passbook',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFEEF2FF),
        elevation: 0,
      ),
      body: _isLoading
          ? const PassbookShimmer()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Gradient Balance Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4285F4), Color(0xFF7B61FF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4285F4).withOpacity(0.3),
                              blurRadius: 15,
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
                                  'TOTAL BALANCE',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
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
                              _formatBalance(_currentUser?.balance ?? 0),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _showAddFundsDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 16, color: const Color(0xFF4285F4)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Add Funds',
                                      style: TextStyle(
                                        color: const Color(0xFF4285F4),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Summary Statistics - White cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.north_east, 
                                        color: Colors.orange[700], size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Sent',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _formatAmount(_totalSent),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.south_west, 
                                        color: Colors.green[600], size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Received',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _formatAmount(_totalReceived),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // History Header with Filter
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          InkWell(
                            onTap: _showFilterMenu,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    _filterType,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.grey[800],
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Transaction List
                    _filteredTransactions.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long,
                                      size: 80, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No transactions found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildGroupedTransactionList(),
                            ),
                          ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> trans) {
    final amount = (trans['amount'] ?? 0).toDouble();
    final type = trans['transaction_type'] ?? '';
    final timestamp = trans['timestamp'] ?? trans['created_at'];
    final status = trans['status'] ?? 'SUCCESS';

    // Determine if this is sent or received
    String displayName = 'Unknown';
    bool isSent = false;
    String paymentMethod = 'Vai UPI';
    String? profilePicUrl;

    if (type == 'TRANSFER') {
      // Sent: receiver_name has the other person
      final receiverName = trans['receiver_name']?.toString() ?? '';
      final receiverId = trans['receiver_id']?.toString() ?? '';
      displayName = receiverName.isNotEmpty && receiverName != 'You'
          ? receiverName : 'Unknown';
      isSent = true;
      profilePicUrl = _contactProfilePics[receiverId] ?? _contactProfilePics[displayName];
    } else if (type == 'RECEIVED') {
      // Received: sender_name has the other person
      final senderName = trans['sender_name']?.toString() ?? '';
      final senderId = trans['sender_id']?.toString() ?? '';
      displayName = senderName.isNotEmpty && senderName != 'You'
          ? senderName : 'Unknown';
      isSent = false;
      profilePicUrl = _contactProfilePics[senderId] ?? _contactProfilePics[displayName];
    } else if (type == 'DEPOSIT') {
      displayName = 'Bank';
      isSent = false;
      paymentMethod = 'Deposit';
    }

    final avatarLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final isFlagged = status.toString().toUpperCase() == 'FLAGGED';
    final isSuccess = status.toString().toUpperCase() == 'SUCCESS' || isFlagged;
    final timeStr = _formatTime(timestamp);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: type == 'DEPOSIT'
                ? const Color(0xFF4285F4).withOpacity(0.15)
                : Colors.grey[200],
            backgroundImage: profilePicUrl != null
                ? NetworkImage(profilePicUrl)
                : null,
            child: profilePicUrl == null
                ? Text(
                    avatarLetter,
                    style: TextStyle(
                      color: type == 'DEPOSIT'
                          ? const Color(0xFF4285F4)
                          : Colors.grey[700],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSent ? 'Send to $displayName' : 'Received from $displayName',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$paymentMethod • $timeStr',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Amount and Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatAmount(amount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSuccess ? Icons.check : Icons.close,
                    color: isSuccess ? Colors.green : Colors.red,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    isSuccess ? 'Success' : 'Failed',
                    style: TextStyle(
                      color: isSuccess ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
