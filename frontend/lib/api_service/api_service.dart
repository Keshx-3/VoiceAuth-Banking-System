import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Custom exception for authentication errors
class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);
  
  @override
  String toString() => message;
}

// Custom exception for suspended/frozen accounts (fraud detection)
class AccountSuspendedException implements Exception {
  final String message;
  AccountSuspendedException(this.message);
  
  @override
  String toString() => message;
}

// Custom exception for probable fraud detection (flag_score > 0)
class ProbableFraudException implements Exception {
  final String explanation;
  final int fraudScore;
  ProbableFraudException({required this.explanation, required this.fraudScore});

  @override
  String toString() => explanation;
}

// Result class for voice verification
class VoiceVerificationResult {
  final bool authenticated;
  final double similarity;

  VoiceVerificationResult({
    required this.authenticated,
    required this.similarity,
  });

  /// Similarity as percentage (0-100)
  double get similarityPercent => similarity * 100;
}

class BankingApiService {
  static final BankingApiService _instance = BankingApiService._internal();

  factory BankingApiService() {
    return _instance;
  }

  BankingApiService._internal();

  // Replace with your actual API URL
  static const String baseUrl = "https://13.202.14.245.nip.io";
  static const String _tokenKey = 'auth_token';

  // Store access token in memory
  String? _accessToken;

  // Initialize and try to load token
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
  }

  // Helper to get headers
  Map<String, String> get _jsonHeaders {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
  }

  Map<String, String> get _authHeaders {
    return {
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
  }

  bool get isLoggedIn => _accessToken != null;

  // --- 1. AUTHENTICATION ---

  /// Endpoint: POST /api/v1/auth/signup
  /// Handles Multipart form-data for profile picture upload
  Future<Map<String, dynamic>> signup({
    required String fullName,
    required String phoneNumber,
    required String password,
    File? profilePic,
  }) async {
    var uri = Uri.parse('$baseUrl/api/v1/auth/signup');
    var request = http.MultipartRequest('POST', uri);

    request.fields['full_name'] = fullName;
    request.fields['phone_number'] = phoneNumber;
    request.fields['password'] = password;

    if (profilePic != null) {
      // Determine content type based on file extension
      final extension = profilePic.path.toLowerCase().split('.').last;
      final contentType = extension == 'png' 
          ? MediaType('image', 'png')
          : MediaType('image', 'jpeg');
      
      request.files.add(await http.MultipartFile.fromPath(
        'profile_pic',
        profilePic.path,
        contentType: contentType,
      ));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    return await _processResponse(response);
  }

  /// Endpoint: POST /api/v1/auth/login
  Future<Map<String, dynamic>> login(String username, String password) async {
    // Postman collection uses form-data for login
    var uri = Uri.parse('$baseUrl/api/v1/auth/login');
    var request = http.MultipartRequest('POST', uri);

    request.fields['username'] = username;
    request.fields['password'] = password;

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    final data = await _processResponse(response);

    // Automatically save token if present in response
    if (data.containsKey('access_token')) {
      _accessToken = data['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _accessToken!);
    }

    return data;
  }

  /// Endpoint: POST /api/v1/auth/refresh
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    return await _processResponse(response);
  }

  /// Endpoint: POST /api/v1/auth/logout
  Future<void> logout() async {
    // Note: The API might expect a refresh token, but for now we just clear local state
    // If the API requires a call, we can add it here.
    // await http.post(
    //   Uri.parse('$baseUrl/auth/logout'),
    //   headers: _jsonHeaders,
    //   body: jsonEncode({'refresh_token': refreshToken}),
    // );
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // --- 2. USER MANAGEMENT ---

  /// Endpoint: GET /api/v1/users/me
  Future<Map<String, dynamic>> getUserDetails() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/users/me'),
      headers: _authHeaders,
    );
    return await _processResponse(response);
  }

  /// Endpoint: POST /api/v1/users/me/avatar
  Future<Map<String, dynamic>> changeProfilePic(File profilePic) async {
    var uri = Uri.parse('$baseUrl/api/v1/users/me/avatar');
    var request = http.MultipartRequest('POST', uri);

    // Add Headers manually for Multipart request
    request.headers.addAll(_authHeaders);
    request.headers['Accept'] = 'application/json';

    // Read file as bytes for reliable upload
    final bytes = await profilePic.readAsBytes();

    // Determine content type and filename based on file extension
    final ext = profilePic.path.toLowerCase().split('.').last;
    MediaType contentType;
    String filename;
    switch (ext) {
      case 'png':
        contentType = MediaType('image', 'png');
        filename = 'profile.png';
        break;
      case 'webp':
        contentType = MediaType('image', 'webp');
        filename = 'profile.webp';
        break;
      case 'heic':
      case 'heif':
        contentType = MediaType('image', 'heic');
        filename = 'profile.heic';
        break;
      default:
        // Default to JPEG for jpg, jpeg, or unknown extensions
        contentType = MediaType('image', 'jpeg');
        filename = 'profile.jpg';
        break;
    }

    request.files.add(http.MultipartFile.fromBytes(
      'profile_pic',
      bytes,
      filename: filename,
      contentType: contentType,
    ));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    return await _processResponse(response);
  }

  /// Endpoint: GET /api/v1/users/contacts
  Future<List<dynamic>> getRecentContacts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/users/contacts'),
      headers: _authHeaders,
    );
    return await _processResponse(response) as List<dynamic>;
  }

  /// Endpoint: GET /api/v1/users/search
  Future<List<dynamic>> searchUsers(String query) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/search').replace(queryParameters: {
      'query': query,
    });

    final response = await http.get(
      uri,
      headers: _authHeaders,
    );
    return await _processResponse(response) as List<dynamic>;
  }

  // --- 3. TRANSACTIONS ---

  /// Endpoint: POST /api/v1/transactions/deposit
  Future<Map<String, dynamic>> deposit(double amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/transactions/deposit'),
      headers: _jsonHeaders,
      body: jsonEncode({'amount': amount}),
    );
    return await _processResponse(response);
  }

  /// Endpoint: POST /api/v1/transactions/transfer
  Future<Map<String, dynamic>> transfer(String receiverPhone, double amount, {String? description, bool confirmFraud = false}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/transactions/transfer'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'receiver_phone': receiverPhone,
        'amount': amount,
        if (description != null) 'description': description,
        if (confirmFraud) 'confirm_fraud': true,
      }),
    );

    // Intercept the 403 Forbidden response to extract the fraud flag
    if (response.statusCode == 403) {
      final responseBody = jsonDecode(response.body);

      // Check if the nested message contains "PROBABLE_FRAUD"
      if (responseBody['message'] != null && responseBody['message']['message'] == 'PROBABLE_FRAUD') {
        // Return the parsed body so your UI layer can access the explanation
        return responseBody;
      }
    }

    // For all other status codes, proceed with your normal error handling/parsing
    return await _processResponse(response);
  }

  /// Endpoint: GET /api/v1/transactions/history
  Future<List<dynamic>> getTransactionHistory({int? limit}) async {
    final Map<String, dynamic> queryParams = {};
    if (limit != null) queryParams['limit'] = limit.toString();

    final uri = Uri.parse('$baseUrl/api/v1/transactions/history')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: _authHeaders,
    );
    return await _processResponse(response) as List<dynamic>;
  }

  /// Endpoint: GET /api/v1/transactions/chat/{userId}
  Future<List<dynamic>> getTransactionChat(String otherUserId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/transactions/chat/$otherUserId'),
      headers: _authHeaders,
    );
    return await _processResponse(response) as List<dynamic>;
  }

  // --- 4. VOICE AUTH TOGGLE ---

  /// Endpoint: GET /api/v1/users/me/voice-auth
  /// Check if voice authentication is enabled for payments
  /// API returns a plain boolean: true or false
  Future<bool> getVoiceAuthStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/users/me/voice-auth'),
      headers: _authHeaders,
    );
    final data = await _processResponse(response);
    // API returns a plain boolean, not a JSON object
    if (data is bool) {
      return data;
    }
    // Fallback: check if it's a map with a known key
    if (data is Map<String, dynamic>) {
      return data['voice_auth'] == true || data['noise_active'] == true;
    }
    return false;
  }

  /// Endpoint: POST /api/v1/users/me/voice-auth
  /// Toggle voice authentication on/off (no body needed, API just flips the state)
  /// API returns a plain boolean: the new state
  Future<bool> toggleVoiceAuth() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/users/me/voice-auth'),
      headers: _authHeaders,
    );
    final data = await _processResponse(response);
    // API returns a plain boolean, not a JSON object
    if (data is bool) {
      return data;
    }
    // Fallback: check if it's a map with a known key
    if (data is Map<String, dynamic>) {
      return data['voice_auth'] == true || data['noise_active'] == true;
    }
    return false;
  }

  // --- 5. VOICE AUTHENTICATION ---

  /// Endpoint: POST /voice/register
  /// Accepts two 5-second audio samples for voice registration
  Future<Map<String, dynamic>> registerVoice(File audioFile1, File audioFile2) async {
    var uri = Uri.parse('$baseUrl/voice/register');
    var request = http.MultipartRequest('POST', uri);

    // Add Headers manually for Multipart request
    request.headers.addAll(_authHeaders);

    // Add first audio file with explicit WAV content type
    request.files.add(await http.MultipartFile.fromPath(
      'audio_files',  // Correct field name for the API
      audioFile1.path,
      contentType: MediaType('audio', 'wav'),
    ));

    // Add second audio file with explicit WAV content type
    request.files.add(await http.MultipartFile.fromPath(
      'audio_files',  // Same field name for multiple files
      audioFile2.path,
      contentType: MediaType('audio', 'wav'),
    ));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    return await _processResponse(response);
  }

  /// Endpoint: POST /voice/verify
  /// Verifies user's voice before payment
  /// Returns a VoiceVerificationResult with authenticated status and similarity score
  Future<VoiceVerificationResult> verifyVoice(File audioFile) async {
    var uri = Uri.parse('$baseUrl/voice/verify');
    var request = http.MultipartRequest('POST', uri);

    // Add Headers
    request.headers['accept'] = 'application/json';
    request.headers.addAll(_authHeaders);

    // Add audio file
    request.files.add(await http.MultipartFile.fromPath(
      'audio',  // Field name as per API specification
      audioFile.path,
      contentType: MediaType('audio', 'wav'),
    ));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      // Parse the response to get authenticated status and similarity
      final responseData = jsonDecode(response.body);
      final bool authenticated = responseData['authenticated'] ?? false;
      final double similarity = (responseData['similarity'] ?? 0.0).toDouble();
      
      return VoiceVerificationResult(
        authenticated: authenticated,
        similarity: similarity,
      );
    } else if (response.statusCode == 401) {
      // Handle authentication errors
      _accessToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      throw AuthenticationException('Your session has expired. Please log in again.');
    } else if (response.statusCode == 422) {
      throw Exception('Voice verification failed. Please try again.');
    } else {
      // Try to parse error message
      String message = 'Voice verification failed';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('detail')) {
          message = errorBody['detail'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  /// Verify PIN for payment fallback
  /// Since PIN = password, this validates by attempting login with stored phone and entered PIN
  Future<bool> verifyPin(String pin) async {
    // Get the stored phone number from user details
    try {
      final userDetails = await getUserDetails();
      final phoneNumber = userDetails['phone_number'] as String?;
      
      if (phoneNumber == null) {
        throw Exception('Unable to verify PIN. Please try again.');
      }

      // Try to login with the phone number and PIN
      // If it succeeds, the PIN is correct
      var uri = Uri.parse('$baseUrl/api/v1/auth/login');
      var request = http.MultipartRequest('POST', uri);
      request.fields['username'] = phoneNumber;
      request.fields['password'] = pin;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // PIN is correct - update token if new one was issued
        final data = jsonDecode(response.body);
        if (data.containsKey('access_token')) {
          _accessToken = data['access_token'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, _accessToken!);
        }
        return true;
      } else {
        throw Exception('Incorrect PIN');
      }
    } catch (e) {
      if (e.toString().contains('Incorrect PIN')) {
        rethrow;
      }
      throw Exception('PIN verification failed. Please try again.');
    }
  }

  // --- 6. PAYMENT REQUESTS ---

  /// Endpoint: POST /api/v1/requests/
  /// Create a payment request to another user
  Future<Map<String, dynamic>> createPaymentRequest(double amount, String payerPhone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/requests/'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'amount': amount,
        'payer_phone': payerPhone,
      }),
    );
    return await _processResponse(response);
  }

  /// Endpoint: GET /api/v1/requests/
  /// Get all payment requests for the current user
  Future<List<dynamic>> getPaymentRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/requests/'),
      headers: _authHeaders,
    );
    return await _processResponse(response) as List<dynamic>;
  }

  /// Endpoint: POST /api/v1/requests/{request_id}/{action}
  /// Accept or reject a payment request
  /// action should be "accept" or "reject" (lowercase, case-sensitive)
  Future<Map<String, dynamic>> respondToPaymentRequest(int requestId, String action) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/requests/$requestId/$action'),
      headers: _jsonHeaders,
    );
    return await _processResponse(response);
  }

  // --- HELPER METHODS ---

  dynamic _processResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Decode JSON if the body is not empty
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
      return {};
    } else if (response.statusCode == 401) {
      // Handle authentication errors specifically
      // Clear the invalid token
      _accessToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      
      throw AuthenticationException(
        'Your session has expired. Please log in again.'
      );
    } else if (response.statusCode == 403) {
      // Check for account suspension or probable fraud detection
      String message = 'Access forbidden';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map) {
          // Check for PROBABLE_FRAUD nested message object
          final msgField = errorBody['message'];
          if (msgField is Map && msgField['message'] == 'PROBABLE_FRAUD') {
            throw ProbableFraudException(
              explanation: msgField['explanation'] ?? 'This transaction looks suspicious.',
              fraudScore: msgField['fraud_score'] ?? 0,
            );
          }
          message = (msgField is String ? msgField : null) ?? errorBody['detail'] ?? message;
        }
      } on ProbableFraudException {
        rethrow;
      } catch (_) {}
      
      // Check if this is a fraud/suspension related 403
      final lowerMsg = message.toLowerCase();
      if (lowerMsg.contains('suspicious') || lowerMsg.contains('under review') ||
          lowerMsg.contains('suspended') || lowerMsg.contains('frozen')) {
        throw AccountSuspendedException(message);
      }
      throw Exception(message);
    } else {
      // Handle other errors
      // Try to decode error message
      String message = 'API Error: ${response.statusCode}';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map) {
          if (errorBody.containsKey('detail')) {
            // Handle both string and list details
            final detail = errorBody['detail'];
            if (detail is String) {
              message = detail;
            } else if (detail is List && detail.isNotEmpty) {
              // FastAPI validation errors are often in list format
              message = detail.map((e) => e['msg'] ?? e.toString()).join(', ');
            } else {
              message = detail.toString();
            }
          } else if (errorBody.containsKey('message')) {
            message = errorBody['message'];
          } else if (errorBody.containsKey('error')) {
            message = errorBody['error'];
          } else {
            // Show the full response for debugging
            message = 'API Error ${response.statusCode}: ${response.body}';
          }
        }
      } catch (_) {
        message = 'API Error ${response.statusCode}: ${response.body}';
      }
      throw Exception(message);
    }
  }
}
