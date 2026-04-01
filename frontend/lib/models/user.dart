// lib/models/user.dart
class User {
  final String id;
  final String fullName;
  final String phoneNumber;
  final double balance;
  final String? profilePicUrl;
  final DateTime? createdAt;
  final bool? noiseActive;

  User({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.balance,
    this.profilePicUrl,
    this.createdAt,
    this.noiseActive,
  });

  // Base URL for constructing full image URLs
  static const String _baseUrl = "https://13.202.14.245.nip.io";

  // Factory constructor to create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    // Get the raw profile pic value
    String? rawProfilePic = json['profile_pic_url'] ?? json['profile_pic'] ?? json['profilePicUrl'];
    
    // Construct full URL if it's a relative path
    String? fullProfilePicUrl;
    if (rawProfilePic != null && rawProfilePic.isNotEmpty) {
      if (rawProfilePic.startsWith('http://') || rawProfilePic.startsWith('https://')) {
        // Already a full URL
        fullProfilePicUrl = rawProfilePic;
      } else if (rawProfilePic.startsWith('/')) {
        // Relative path - prepend base URL
        fullProfilePicUrl = '$_baseUrl$rawProfilePic';
      } else {
        // Relative path without leading slash
        fullProfilePicUrl = '$_baseUrl/$rawProfilePic';
      }
    }

    return User(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      profilePicUrl: fullProfilePicUrl,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      noiseActive: json['noise_active'],
    );
  }

  // Convert User to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'balance': balance,
      'profile_pic_url': profilePicUrl,
      'created_at': createdAt?.toIso8601String(),
      'noise_active': noiseActive,
    };
  }

  // Create a copy with updated fields
  User copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    double? balance,
    String? profilePicUrl,
    DateTime? createdAt,
    bool? noiseActive,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      balance: balance ?? this.balance,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      createdAt: createdAt ?? this.createdAt,
      noiseActive: noiseActive ?? this.noiseActive,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, fullName: $fullName, phoneNumber: $phoneNumber, balance: $balance)';
  }
}
