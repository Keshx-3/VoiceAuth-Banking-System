// lib/services/transaction_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import 'package:uuid/uuid.dart';
import 'user_preferences_service.dart';

// ⚠️ DEPRECATED: This service is no longer used for transactions.
// All transaction operations are now handled by BankingApiService (lib/api_service/api_service.dart).
// This file is kept only for reference and may be removed in the future.

class TransactionService {
  static const double _defaultInitialBalance = 15000.0;

  // Helper method to get user-specific key
  static Future<String?> _getUserKey(String suffix) async {
    final userId = await UserPreferencesService.getCurrentUserId();
    if (userId == null) return null;
    return 'user_${userId}_$suffix';
  }

  // Initialize user with default balance if first time
  static Future<void> initializeBalance() async {
    final key = await _getUserKey('initial_balance');
    if (key == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(key)) {
      await prefs.setDouble(key, _defaultInitialBalance);
    }
  }

  // Get initial balance for current user
  static Future<double> getInitialBalance() async {
    final key = await _getUserKey('initial_balance');
    if (key == null) return _defaultInitialBalance;
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(key) ?? _defaultInitialBalance;
  }

  // Save a new transaction for current user
  static Future<bool> saveTransaction(Transaction transaction) async {
    try {
      final key = await _getUserKey('transactions');
      if (key == null) return false;
      
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing transactions
      final transactions = await getAllTransactions();
      
      // Add new transaction
      transactions.add(transaction);
      
      // Convert to JSON
      final jsonList = transactions.map((t) => t.toJson()).toList();
      final jsonString = json.encode(jsonList);
      
      // Save to preferences
      await prefs.setString(key, jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get all transactions for current user
  static Future<List<Transaction>> getAllTransactions() async {
    try {
      final key = await _getUserKey('transactions');
      if (key == null) return [];
      
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(key);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final jsonList = json.decode(jsonString) as List;
      return jsonList.map((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Calculate current balance for current user
  static Future<double> getCurrentBalance() async {
    final initialBalance = await getInitialBalance();
    final transactions = await getAllTransactions();
    
    double totalSent = 0;
    double totalReceived = 0;
    
    for (var transaction in transactions) {
      if (transaction.isReceived) {
        totalReceived += transaction.amount;
      } else {
        totalSent += transaction.amount;
      }
    }
    
    return initialBalance - totalSent + totalReceived;
  }

  // Create a new transaction (helper method)
  static Transaction createTransaction({
    required String name,
    required double amount,
    required bool isReceived,
    String description = '',
  }) {
    final now = DateTime.now();
    final uuid = const Uuid();
    
    // Format date
    String formattedDate;
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (now.year == today.year && now.month == today.month && now.day == today.day) {
      formattedDate = 'Today, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    } else if (now.year == yesterday.year && now.month == yesterday.month && now.day == yesterday.day) {
      formattedDate = 'Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      formattedDate = '${months[now.month - 1]} ${now.day}';
    }
    
    return Transaction(
      id: uuid.v4(),
      name: name,
      date: formattedDate,
      amount: amount,
      isReceived: isReceived,
      avatarLetter: name.isNotEmpty ? name[0].toUpperCase() : 'U',
      description: description,
      timestamp: now,
    );
  }

  // Clear all transactions for current user (for testing)
  static Future<void> clearAllTransactions() async {
    final key = await _getUserKey('transactions');
    if (key == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // Reset to initial state for current user (for testing)
  static Future<void> resetAll() async {
    final transactionsKey = await _getUserKey('transactions');
    final balanceKey = await _getUserKey('initial_balance');
    if (transactionsKey == null || balanceKey == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(transactionsKey);
    await prefs.setDouble(balanceKey, _defaultInitialBalance);
  }
}
