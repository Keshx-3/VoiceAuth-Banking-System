// lib/models/transaction.dart

class Transaction {
  final String id;
  final String name;
  final String date;
  final double amount;
  final bool isReceived; // true if received, false if sent
  final String avatarLetter;
  final String description;
  final DateTime timestamp;

  Transaction({
    required this.id,
    required this.name,
    required this.date,
    required this.amount,
    required this.isReceived,
    required this.avatarLetter,
    required this.description,
    required this.timestamp,
  });

  // Convert Transaction to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': date,
      'amount': amount,
      'isReceived': isReceived,
      'avatarLetter': avatarLetter,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Create Transaction from JSON Map
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      name: json['name'] as String,
      date: json['date'] as String,
      amount: (json['amount'] as num).toDouble(),
      isReceived: json['isReceived'] as bool,
      avatarLetter: json['avatarLetter'] as String,
      description: json['description'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
