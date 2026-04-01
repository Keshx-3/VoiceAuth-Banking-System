// lib/screens/contact_chat_screen.dart
import 'package:flutter/material.dart';
import '../api_service/api_service.dart';
import 'send_money_screen.dart';
import 'request_money_screen.dart';

class ContactChatScreen extends StatefulWidget {
  final String contactName;
  final String contactPhone;
  final String contactId;

  const ContactChatScreen({
    super.key,
    required this.contactName,
    required this.contactPhone,
    required this.contactId,
  });

  @override
  State<ContactChatScreen> createState() => _ContactChatScreenState();
}

class _ContactChatScreenState extends State<ContactChatScreen> {
  List<dynamic> _transactions = [];
  List<dynamic> _requests = [];
  bool _isLoading = true;
  bool _hasNewTransaction = false;
  int? _currentUserId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _initData() async {
    await _loadCurrentUser();
    _loadAllData();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userDetails = await BankingApiService().getUserDetails();
      if (mounted) {
        setState(() {
          _currentUserId = userDetails['id'];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        BankingApiService().getTransactionChat(widget.contactId),
        BankingApiService().getPaymentRequests(),
      ]);

      if (mounted) {
        final allRequests = results[1] as List<dynamic>;
        final contactIdInt = int.tryParse(widget.contactId);

        // Collect request IDs so we can filter them from transactions
        final Set<int> requestIds = {};
        for (final req in allRequests) {
          if (req['id'] != null) requestIds.add(req['id']);
        }

        // Filter requests relevant to this contact (show ALL statuses including ACCEPTED)
        final filteredRequests = allRequests.where((req) {
          final requesterId = req['requester_id'];
          final payerId = req['payer_id'];
          final isRelevant = (requesterId == contactIdInt || payerId == contactIdInt);
          return isRelevant;
        }).toList();

        // Collect accepted request amounts for deduplication with transactions
        final List<double> acceptedAmountsToDedup = [];
        for (final req in filteredRequests) {
          final status = (req['status'] ?? '').toString().toUpperCase();
          if (status == 'ACCEPTED') {
            acceptedAmountsToDedup.add((req['amount'] ?? 0).toDouble());
          }
        }

        // Build a set of all request timestamps for cross-referencing
        final Set<String> requestTimestamps = {};
        for (final req in allRequests) {
          final ts = req['created_at']?.toString();
          if (ts != null && ts.isNotEmpty) requestTimestamps.add(ts);
        }

        // Filter transactions: aggressively remove any request entries
        final rawTransactions = results[0] as List<dynamic>;
        final cleanTransactions = rawTransactions.where((t) {
          // Filter 1: Has request-specific fields (requester_id, payer_id, etc.)
          if (t['requester_id'] != null || t['payer_id'] != null ||
              t['requester_name'] != null || t['payer_name'] != null) {
            return false;
          }

          // Filter 2: Has a request-like status (PENDING, REJECTED, ACCEPTED)
          final status = (t['status'] ?? '').toString().toUpperCase();
          if (status == 'PENDING' || status == 'REJECTED' || status == 'ACCEPTED') {
            return false;
          }

          // Filter 3: Must have proper sender/receiver info (real transactions always do)
          final hasSenderReceiver =
              (t['sender_name'] != null && t['sender_name'].toString().isNotEmpty) ||
              (t['receiver_name'] != null && t['receiver_name'].toString().isNotEmpty) ||
              t['sender_id'] != null || t['receiver_id'] != null ||
              t['sender'] != null || t['receiver'] != null;
          if (!hasSenderReceiver) {
            return false;
          }

          // Filter 4: Cross-reference — skip if timestamp matches a known request
          final txTs = (t['timestamp'] ?? t['created_at'] ?? '').toString();
          if (txTs.isNotEmpty && requestTimestamps.contains(txTs)) {
            return false;
          }

          return true;
        }).toList();

        // Deduplicate: remove one transaction per accepted request (same amount)
        final dedupedTransactions = <dynamic>[];
        for (final t in cleanTransactions) {
          final amount = (t['amount'] ?? 0).toDouble();
          if (acceptedAmountsToDedup.contains(amount)) {
            acceptedAmountsToDedup.remove(amount); // consume one match
            continue; // skip this duplicate transaction
          }
          dedupedTransactions.add(t);
        }

        setState(() {
          _transactions = dedupedTransactions;
          _requests = filteredRequests;
          _isLoading = false;
        });
        _scrollToBottom();
      }
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

  /// Extract the best date value from a data item
  dynamic _extractDate(dynamic item) {
    if (item is Map) {
      // Try multiple date fields in priority order
      return item['timestamp'] ?? item['created_at'] ?? item['date'] ?? '';
    }
    return '';
  }

  /// Build a combined timeline sorted by date
  List<Map<String, dynamic>> get _combinedTimeline {
    final List<Map<String, dynamic>> combined = [];

    for (final trans in _transactions) {
      final dateVal = _extractDate(trans);
      combined.add({
        'type': 'transaction',
        'data': trans,
        'sortMs': _dateToMillis(dateVal),
      });
    }

    for (final req in _requests) {
      final dateVal = _extractDate(req);
      combined.add({
        'type': 'request',
        'data': req,
        'sortMs': _dateToMillis(dateVal),
      });
    }

    // Sort ASCENDING by milliseconds — oldest first (top), newest last (bottom)
    combined.sort((a, b) {
      final msA = a['sortMs'] as int;
      final msB = b['sortMs'] as int;
      return msA.compareTo(msB);
    });

    return combined;
  }

  /// Convert any date value to milliseconds since epoch for reliable sorting.
  int _dateToMillis(dynamic dateValue) {
    if (dateValue == null) return 0;

    // Handle integer (epoch seconds or milliseconds)
    if (dateValue is int) {
      return dateValue > 9999999999 ? dateValue : dateValue * 1000;
    }
    if (dateValue is double) {
      final ms = dateValue > 9999999999 ? dateValue.toInt() : (dateValue * 1000).toInt();
      return ms;
    }

    // Handle string timestamps
    final dateStr = dateValue.toString().trim();
    if (dateStr.isEmpty) return 0;

    // Try parsing as a number string (epoch)
    final asNum = int.tryParse(dateStr) ?? double.tryParse(dateStr)?.toInt();
    if (asNum != null) {
      return asNum > 9999999999 ? asNum : asNum * 1000;
    }

    // Try ISO 8601 parse (handles most standard formats)
    try {
      // Normalize nanoseconds: truncate fractional seconds to 6 digits max
      String normalized = dateStr;
      final dotIndex = normalized.indexOf('.');
      if (dotIndex > 0) {
        int endIndex = normalized.length;
        for (int i = dotIndex + 1; i < normalized.length; i++) {
          final c = normalized[i];
          if (c == 'Z' || c == '+' || c == '-') {
            endIndex = i;
            break;
          }
        }
        final fracLen = endIndex - dotIndex - 1;
        if (fracLen > 6) {
          normalized = normalized.substring(0, dotIndex + 7) +
              normalized.substring(endIndex);
        }
      }
      return DateTime.parse(normalized).millisecondsSinceEpoch;
    } catch (_) {}

    // Try common non-ISO formats: "dd-MM-yyyy HH:mm:ss" or "yyyy/MM/dd HH:mm:ss"
    try {
      final parts = dateStr.split(RegExp(r'[T ]'));
      if (parts.length >= 2) {
        final datePart = parts[0];
        final timePart = parts[1].split('.')[0]; // remove fractional
        final sep = datePart.contains('-') ? '-' : '/';
        final dp = datePart.split(sep);
        final tp = timePart.split(':');
        if (dp.length == 3 && tp.length >= 2) {
          int year, month, day;
          if (dp[0].length == 4) {
            year = int.parse(dp[0]); month = int.parse(dp[1]); day = int.parse(dp[2]);
          } else {
            day = int.parse(dp[0]); month = int.parse(dp[1]); year = int.parse(dp[2]);
          }
          return DateTime(year, month, day,
            int.parse(tp[0]),
            int.parse(tp[1]),
            tp.length > 2 ? int.parse(tp[2]) : 0,
          ).millisecondsSinceEpoch;
        }
      }
    } catch (_) {}

    return 0;
  }

  double get _totalPaid {
    return _transactions.fold(0.0, (sum, trans) {
      final type = trans['transaction_type'] ?? '';
      final receiverName = trans['receiver_name'] ?? trans['receiver']?['full_name'] ?? '';
      final amount = (trans['amount'] ?? 0).toDouble();
      if (type == 'TRANSFER' && receiverName == widget.contactName) {
        return sum + amount;
      }
      return sum;
    });
  }

  double get _totalReceived {
    return _transactions.fold(0.0, (sum, trans) {
      final type = trans['transaction_type'] ?? '';
      final senderName = trans['sender_name'] ?? trans['sender']?['full_name'] ?? '';
      final amount = (trans['amount'] ?? 0).toDouble();
      if (type == 'TRANSFER' && senderName == widget.contactName) {
        return sum + amount;
      }
      return sum;
    });
  }

  /// Robustly parse a date string, handling ISO 8601 and DD-MM-YYYY formats.
  DateTime? _tryParseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final s = dateStr.trim();

    // Try standard ISO 8601 first
    try {
      return DateTime.parse(s);
    } catch (_) {}

    // Try DD-MM-YYYY HH:MM:SS or DD-MM-YYYY HH:MM
    try {
      final parts = s.split(RegExp(r'[T ]'));
      if (parts.isNotEmpty) {
        final datePart = parts[0];
        final sep = datePart.contains('-') ? '-' : '/';
        final dp = datePart.split(sep);
        if (dp.length == 3) {
          int year, month, day;
          if (dp[0].length == 4) {
            // YYYY-MM-DD
            year = int.parse(dp[0]); month = int.parse(dp[1]); day = int.parse(dp[2]);
          } else {
            // DD-MM-YYYY
            day = int.parse(dp[0]); month = int.parse(dp[1]); year = int.parse(dp[2]);
          }
          int hour = 0, minute = 0, second = 0;
          if (parts.length >= 2) {
            final tp = parts[1].split('.')[0].split(':');
            hour = int.parse(tp[0]);
            minute = tp.length > 1 ? int.parse(tp[1]) : 0;
            second = tp.length > 2 ? int.parse(tp[2]) : 0;
          }
          return DateTime(year, month, day, hour, minute, second);
        }
      }
    } catch (_) {}

    return null;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown date';
    final date = _tryParseDate(dateStr);
    if (date == null) return dateStr;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute';
  }

  String _formatTimeLabel(String? dateStr) {
    if (dateStr == null) return '';
    final date = _tryParseDate(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (txDate == today) {
      return 'Today, $time';
    } else if (txDate == yesterday) {
      return 'Yesterday, $time';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]}, $time';
    }
  }

  Future<void> _handleAcceptRequest(Map<String, dynamic> request) async {
    final requestId = request['id'] as int;
    final amount = (request['amount'] ?? 0).toDouble();

    try {
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SendMoneyScreen(
              userName: widget.contactName,
              userPhone: widget.contactPhone,
              initialAmount: amount,
            ),
          ),
        );

        if (result == true) {
          // Only mark the request as accepted after payment succeeds
          await BankingApiService().respondToPaymentRequest(requestId, 'accept');
          _hasNewTransaction = true;
        }
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRejectRequest(Map<String, dynamic> request) async {
    final requestId = request['id'] as int;
    try {
      await BankingApiService().respondToPaymentRequest(requestId, 'reject');
      if (mounted) {
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject request: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarLetter = widget.contactName.isNotEmpty
        ? widget.contactName[0].toUpperCase()
        : 'U';

    final timeline = _combinedTimeline;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _hasNewTransaction);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F8FF),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context, _hasNewTransaction),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue[200],
                child: Text(
                  avatarLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.contactName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      widget.contactPhone,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.more_vert, color: Colors.grey[700]),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            // Summary cards
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withAlpha(20),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text('Amount Paid', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 6),
                          Text(
                            '₹${_totalPaid.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A44B8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withAlpha(15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text('Amount Received', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 6),
                          Text(
                            '₹${_totalReceived.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(
                                0xFF222ED8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE8EDF5)),

            // Timeline
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : timeline.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('No transactions yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                              const SizedBox(height: 8),
                              Text(
                                'Start by sending money to ${widget.contactName}',
                                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAllData,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                            itemCount: timeline.length,
                            itemBuilder: (context, index) {
                              final item = timeline[index];
                              if (item['type'] == 'request') {
                                return _buildRequestCard(item['data']);
                              }
                              return _buildTransactionBubble(item['data']);
                            },
                          ),
                        ),
            ),
          ],
        ),
        // Dual FAB
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FloatingActionButton.extended(
                    heroTag: 'pay_fab',
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SendMoneyScreen(
                            userName: widget.contactName,
                            userPhone: widget.contactPhone,
                          ),
                        ),
                      );
                      if (result == true) {
                        _hasNewTransaction = true;
                        _loadAllData();
                      }
                    },
                    backgroundColor: const Color(0xFF2979FF),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: const Text('Pay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FloatingActionButton.extended(
                    heroTag: 'request_fab',
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RequestMoneyScreen(
                            userName: widget.contactName,
                            userPhone: widget.contactPhone,
                          ),
                        ),
                      );
                      if (result == true) {
                        _loadAllData();
                      }
                    },
                    backgroundColor: const Color(0xFF2979FF),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    icon: const Icon(Icons.request_page_rounded, size: 20),
                    label: const Text('Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Transaction Bubble (same as before) ───
  Widget _buildTransactionBubble(Map<String, dynamic> trans) {
    final amount = (trans['amount'] ?? 0).toDouble();
    final description = trans['description'] ?? '';
    final timestamp = trans['timestamp'] ?? trans['created_at'];
    final receiverName = trans['receiver_name'] ?? trans['receiver']?['full_name'] ?? '';
    final bool isSentByYou = (receiverName == widget.contactName);
    final String transStatus = (trans['status'] ?? '').toString().toUpperCase();
    final bool isFlagged = transStatus == 'FLAGGED';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Timestamp chip
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _formatTimeLabel(timestamp),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ),
          Align(
            alignment: isSentByYou ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              decoration: BoxDecoration(
                color: isFlagged
                    ? const Color(0xFFFFF8E1)
                    : (isSentByYou ? Colors.white : const Color(0xFFE8F5E9)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isFlagged
                      ? Colors.amber.withAlpha(120)
                      : (isSentByYou ? const Color(0xFFE0E6EF) : const Color(0xFFC8E6C9)),
                  width: isFlagged ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isFlagged ? Colors.amber : (isSentByYou ? Colors.blueGrey : Colors.green)).withAlpha(12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flagged banner
                  if (isFlagged)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(40),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(17),
                          topRight: Radius.circular(17),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber[800]),
                          const SizedBox(width: 6),
                          Text(
                            'Flagged Transaction',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber[900]),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSentByYou ? 'Send to ${widget.contactName}' : 'Received from ${widget.contactName}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[850])),
                            Text(amount.toStringAsFixed(0), style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.grey[850])),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFlagged ? Icons.warning_amber_rounded : Icons.check_circle,
                              size: 15,
                              color: isFlagged ? Colors.amber[700] : Colors.green[600],
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isFlagged
                                  ? 'Flagged • ${_formatDate(timestamp)}'
                                  : 'Paid • ${_formatDate(timestamp)}',
                              style: TextStyle(fontSize: 12, color: isFlagged ? Colors.amber[800] : Colors.grey[500]),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Request Card (Google Pay style) ───
  Widget _buildRequestCard(Map<String, dynamic> request) {
    final amount = (request['amount'] ?? 0).toDouble();
    final status = (request['status'] ?? 'PENDING').toString().toUpperCase();
    final timestamp = request['created_at'];
    final requesterId = request['requester_id'];
    final requesterName = request['requester_name'] ?? widget.contactName;
    final double fraudScore = (request['fraud_score'] ?? 0).toDouble();
    final String? fraudReason = request['fraud_reason'];
    final bool hasFraudWarning = fraudScore > 0 && fraudReason != null;

    // Current user is the payer → incoming request (they need to pay)
    // Current user is the requester → outgoing request (they asked for money)
    final bool isIncomingRequest = (requesterId != _currentUserId);

    // Determine fraud severity for incoming requests
    final bool isHighSeverity = fraudScore >= 3;
    final Color fraudBannerColor = isHighSeverity ? Colors.red : Colors.amber;
    final Color fraudBannerBg = isHighSeverity ? Colors.red.withAlpha(25) : Colors.amber.withAlpha(25);
    final Color fraudTextColor = isHighSeverity ? Colors.red[900]! : Colors.amber[900]!;
    final Color fraudIconColor = isHighSeverity ? Colors.red[700]! : Colors.amber[800]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Timestamp chip
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _formatTimeLabel(timestamp),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ),

          // Google Pay-style request card
          Align(
            alignment: isIncomingRequest ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: (hasFraudWarning && isIncomingRequest)
                      ? fraudBannerColor.withAlpha(100)
                      : const Color(0xFFE0E6EF),
                  width: (hasFraudWarning && isIncomingRequest) ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fraud warning banner for incoming requests
                  if (hasFraudWarning && isIncomingRequest)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: fraudBannerBg,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(17),
                          topRight: Radius.circular(17),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isHighSeverity ? Icons.gpp_bad_rounded : Icons.warning_amber_rounded,
                            size: 18,
                            color: fraudIconColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isHighSeverity ? '⚠ High Risk — Fraud Warning' : '⚠ Fraud Warning',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: fraudTextColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Fraud Activity Has Been Detected",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: fraudTextColor.withAlpha(200),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Top section with amount
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          isIncomingRequest
                              ? '$requesterName requested ₹${amount.toStringAsFixed(0)}'
                              : 'You requested ₹${amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[850],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Amount display
                        Row(
                          children: [
                            Text(
                              '₹${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Status row
                        Row(
                          children: [
                            Icon(
                              _getStatusIcon(status),
                              size: 14,
                              color: _getStatusColor(status),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              status == 'PENDING'
                                  ? 'Unpaid • ${_formatDate(timestamp)}'
                                  : status == 'ACCEPTED'
                                      ? 'Paid • ${_formatDate(timestamp)}'
                                      : 'Rejected • ${_formatDate(timestamp)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Action area
                  if (status == 'PENDING') ...[
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FC),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        border: Border(
                          top: BorderSide(color: Colors.grey[200]!, width: 1),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: isIncomingRequest
                          ? Row(
                              children: [
                                // Accept (Pay) button
                                Expanded(
                                  child: SizedBox(
                                    height: 42,
                                    child: ElevatedButton(
                                      onPressed: () => _handleAcceptRequest(request),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2979FF),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                        elevation: 0,
                                      ),
                                      child: const Text('Pay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Reject button
                                Expanded(
                                  child: SizedBox(
                                    height: 42,
                                    child: OutlinedButton(
                                      onPressed: () => _handleRejectRequest(request),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red[600],
                                        side: BorderSide(color: Colors.red[300]!),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                      ),
                                      child: const Text('Decline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ] else ...[
                    // Rejected status — just bottom padding
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.grey[600]!;
      case 'REJECTED':
        return Colors.red[600]!;
      case 'ACCEPTED':
        return Colors.green[600]!;
      case 'FLAGGED':
        return Colors.amber[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Icons.radio_button_unchecked;
      case 'REJECTED':
        return Icons.cancel;
      case 'ACCEPTED':
        return Icons.check_circle;
      case 'FLAGGED':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info;
    }
  }
}
