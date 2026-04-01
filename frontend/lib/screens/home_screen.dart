import 'package:flutter/material.dart';
import 'package:googlepay/screens/transaction_passbook_screen.dart';
import 'contact_chat_screen.dart';
import 'send_money_screen.dart';
import 'login_screen.dart';
import '../api_service/api_service.dart';
import '../widgets/shimmer_loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _contacts = [];
  List<dynamic> _searchResults = [];
  List<dynamic> _recentTransactions = [];
  bool _isLoadingContacts = false;
  bool _isLoadingTransactions = false;
  bool _isSearching = false;

  // Build a profile pic lookup map from loaded contacts
  Map<String, String> get _contactProfilePics {
    final Map<String, String> picMap = {};
    for (final contact in _contacts) {
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
    return picMap;
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadTransactions();
  }

  /// Public method to refresh data from outside (e.g. tab switch)
  Future<void> refreshData() async {
    await Future.wait([
      _loadContacts(),
      _loadTransactions(),
    ]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoadingContacts = true);

    try {
      final contacts = await BankingApiService().getRecentContacts();
      debugPrint(contacts.toString());
      setState(() {
        _contacts = contacts;
        _isLoadingContacts = false;
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
        setState(() => _isLoadingContacts = false);
        // Silently fail for contacts - not critical
      }
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoadingTransactions = true);

    try {
      final results = await Future.wait([
        BankingApiService().getTransactionHistory(limit: 5),
      ]);
      final transactions = results[0] as List<dynamic>;

      setState(() {
        _recentTransactions = transactions;
        _isLoadingTransactions = false;
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
        setState(() => _isLoadingTransactions = false);
      }
    }
  }

  Future<void> _runSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await BankingApiService().searchUsers(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
            year = int.parse(dp[0]); month = int.parse(dp[1]); day = int.parse(dp[2]);
          } else {
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
    return '$day-$month-$year • $hour:$minute';
  }


  String _getMonthLabel() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  String _formatAmount(double amount) {
    final intPart = amount.toStringAsFixed(0);
    if (intPart.length <= 3) return intPart;
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
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Determine which users to display
    final displayUsers = _isSearching ? _searchResults : _contacts;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      body: RefreshIndicator(
        onRefresh: refreshData,
        child: CustomScrollView(
          slivers: [
          // --- App Bar ---
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 80.0,
            collapsedHeight: 80.0,
            backgroundColor: const Color(0xFFEEF2FF),
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      // Debounce search
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (_searchController.text == value) {
                          _runSearch(value);
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search users by name or phone",
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon:
                          Icon(Icons.account_circle, color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Banner (Hides on search) ---
                  if (_searchController.text.isEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 170,
                      width: double.infinity,
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
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.currency_rupee,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "Secure Payments",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Safe & instant transfers",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- People Section ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isSearching ? "Search Results" : "Recent Contacts",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_isSearching)
                        Text("${displayUsers.length} results",
                            style: const TextStyle(color: Colors.grey))
                      else if (displayUsers.length > 4)
                        Text(
                          "See all",
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  _isLoadingContacts && !_isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(10.0),
                          child: ContactsShimmer(),
                        )
                      : displayUsers.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  _isSearching
                                      ? "No users found"
                                      : "No recent contacts. Search for users to pay.",
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : _isSearching
                              // Grid for search results
                              ? GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    childAspectRatio: 0.75,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: displayUsers.length,
                                  itemBuilder: (context, index) =>
                                      _buildContactAvatar(displayUsers[index]),
                                )
                              // Horizontal scroll for contacts
                              : SizedBox(
                                  height: 90,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: displayUsers.length > 8
                                        ? 8
                                        : displayUsers.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          right: 16,
                                          left: index == 0 ? 0 : 0,
                                        ),
                                        child: _buildContactAvatar(
                                            displayUsers[index]),
                                      );
                                    },
                                  ),
                                ),

                  // --- Recent Activity Section ---
                  // Only show if we are NOT searching
                  if (_searchController.text.isEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Recent Activity",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          _getMonthLabel(),
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _isLoadingTransactions
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: TransactionsShimmer(),
                          )
                        : _recentTransactions.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Center(
                                  child: Text(
                                    "No transactions yet. Make your first payment!",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemCount: _recentTransactions.length > 5
                                    ? 5
                                    : _recentTransactions.length,
                                itemBuilder: (context, index) {
                                  final trans = _recentTransactions[index];
                                  return _buildTransactionCard(trans);
                                },
                              ),
                    const SizedBox(height: 20), // Bottom padding
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildContactAvatar(Map<String, dynamic> user) {
    final name = user['full_name'] ?? user['name'] ?? 'Unknown';
    final phone = user['phone_number'] ?? user['phone'] ?? '';
    final userId = user['id']?.toString() ?? '0';
    final avatarLetter = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';

    // Build profile pic URL
    String? profilePicUrl;
    final rawPic = user['profile_pic']?.toString();
    if (rawPic != null && rawPic.isNotEmpty) {
      if (rawPic.startsWith('http://') || rawPic.startsWith('https://')) {
        profilePicUrl = rawPic;
      } else if (rawPic.startsWith('/')) {
        profilePicUrl = '${BankingApiService.baseUrl}$rawPic';
      } else {
        profilePicUrl = '${BankingApiService.baseUrl}/$rawPic';
      }
    }

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContactChatScreen(
              contactName: name,
              contactPhone: phone,
              contactId: userId,
            ),
          ),
        );
        if (result == true) {
          _loadTransactions();
          _loadContacts();
        }
      },
      child: SizedBox(
        width: 65,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.primaries[
                  int.parse(userId) % Colors.primaries.length]
                  .withOpacity(0.15),
              backgroundImage: profilePicUrl != null
                  ? NetworkImage(profilePicUrl)
                  : null,
              child: profilePicUrl == null
                  ? Text(
                      avatarLetter,
                      style: TextStyle(
                        color: Colors.primaries[
                            int.parse(userId) % Colors.primaries.length],
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> trans) {
    final amount = (trans['amount'] ?? 0).toDouble();
    final type = trans['transaction_type'] ?? '';
    final timestamp = trans['timestamp'] ?? trans['created_at'];
    final status = trans['status'] ?? 'SUCCESS';

    String displayName = 'Unknown';
    bool isReceived = type == 'DEPOSIT' || type == 'RECEIVED';
    bool isSent = false;

    if (type == 'TRANSFER') {
      // Sent transaction: sender_name == 'You', receiver_name == other person
      final receiverName = trans['receiver_name']?.toString() ?? '';
      displayName = receiverName.isNotEmpty && receiverName != 'You'
          ? 'Sent to $receiverName' : 'Sent';
      isReceived = false;
      isSent = true;
    } else if (type == 'RECEIVED') {
      // Received transaction: sender_name == other person, receiver_name == 'You'
      final senderName = trans['sender_name']?.toString() ?? '';
      displayName = senderName.isNotEmpty && senderName != 'You'
          ? 'Received from $senderName' : 'Received';
      isReceived = true;
    } else if (type == 'DEPOSIT') {
      displayName = 'Bank Deposit';
      isReceived = true;
    }

    final isSuccess = status.toUpperCase() == 'SUCCESS';
    final avatarLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    // Profile pic lookup — prioritize ID matching since names may differ
    final contactPicMap = _contactProfilePics;
    String? profilePicUrl;
    if (type == 'TRANSFER') {
      final lookupId = trans['receiver_id']?.toString() ?? '';
      final lookupName = trans['receiver_name']?.toString() ?? '';
      profilePicUrl = contactPicMap[lookupId] ?? contactPicMap[lookupName];
    } else if (type == 'RECEIVED') {
      final lookupId = trans['sender_id']?.toString() ?? '';
      final lookupName = trans['sender_name']?.toString() ?? '';
      profilePicUrl = contactPicMap[lookupId] ?? contactPicMap[lookupName];
    }

    return Container(
      padding: const EdgeInsets.all(14),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name + Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Amount + Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${isReceived ? '+ ' : '- '}\u20b9${amount == amount.roundToDouble() ? _formatAmount(amount) : amount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isReceived ? Colors.green[700] : Colors.black87,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSuccess && isReceived
                        ? Icons.check
                        : isSent
                            ? Icons.north_east
                            : Icons.check,
                    size: 12,
                    color: isReceived ? Colors.green : Colors.blue[600],
                  ),
                  const SizedBox(width: 2),
                  Text(
                    isReceived ? 'Success' : 'Sent',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isReceived ? Colors.green : Colors.blue[600],
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