import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart';

class AuthProvider with ChangeNotifier {
  final String _baseAuthUrl = "http://localhost:3001/auth";
  final String _baseMarketUrl = "http://localhost:3002/markets";
  final SharedPreferences _prefs;
  final Encrypter _encrypter;

  AuthProvider(this._prefs, this._encrypter);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _userRole;
  String? get userRole => _userRole;

  bool get isLandlord => _userRole == 'LANDLORD';

  String? _userId;
  String? get userId => _userId;

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;

  // Encryption and Decryption Methods
  String _encrypt(String plainText) {
    final iv = IV.fromLength(16); // Generate IV
    final encrypted = _encrypter.encrypt(plainText, iv: iv);
    return "${base64Encode(iv.bytes)}:${encrypted.base64}"; // Store IV with encrypted data
  }

  String _decrypt(String encryptedText) {
    try {
      final parts = encryptedText.split(':');
      if (parts.length != 2) throw Exception("Invalid encrypted format");

      final iv = IV.fromBase64(parts[0]); // Retrieve IV
      final encryptedData = parts[1];

      final decrypted = _encrypter.decrypt64(encryptedData, iv: iv);
      return decrypted;
    } catch (e) {
      print('Decryption error: $e');
      rethrow;
    }
  }

  // Registration Method
  Future<void> register(
    String email,
    String password,
    String role,
    String firstName,
    String lastName,
    DateTime? birthDate,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseAuthUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'role': role,
          'firstName': firstName,
          'lastName': lastName,
          'birthDate': birthDate?.toIso8601String(),
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('data') && data['data'] != null) {
          _userRole = role;
          // Registration successful, now log the user in
          await login(email, password);
        } else {
          _errorMessage = 'Registration failed.';
        }
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        _errorMessage =
            errorData['message'] ?? 'An error occurred. Please try again.';
      }
    } catch (e) {
      _errorMessage = 'An error occurred. Please try again.';
      print('Error during registration: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login Method
  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseAuthUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('data') &&
            data['data'] != null &&
            data['data']['token'] != null) {
          final token = data['data']['token'];
          final encryptedToken = _encrypt(token);
          await _prefs.setString('token', encryptedToken);

          // Decode the token to extract the role
          final parts = token.split('.');
          if (parts.length != 3) {
            throw Exception('Invalid token');
          }
          final payload = json.decode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
          );
          _userRole = payload['role']; // Extract role from the token payload
          _userId = payload['userId']; // Extract user ID from the token payload

          print('Decoded token payload: $payload'); // Debugging
          print('User Role: $_userRole'); // Debugging
          print('User ID: $_userId'); // Debugging

          _errorMessage = null;

          // Fetch markets after successful login
          await fetchMarkets();
        } else {
          _errorMessage = 'Token not found in response.';
        }
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        _errorMessage =
            errorData['message'] ?? 'An error occurred. Please try again.';
      }
    } catch (e) {
      _errorMessage = 'An error occurred. Please try again.';
      print('Error during login: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout Method
  Future<void> logout() async {
    await _prefs.remove('token');
    _userRole = null;
    notifyListeners();
  }

  Future<String?> getToken() async {
    final encryptedToken = _prefs.getString('token');
    if (encryptedToken != null) {
      return _decrypt(encryptedToken);
    }
    return null;
  }

  // Fetch Markets Method

  List<dynamic> _markets = [];
  List<dynamic> get markets => _markets;

  Future<void> fetchMarkets() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Read the encrypted token from SharedPreferences
      final encryptedToken = _prefs.getString('token');
      if (encryptedToken == null) {
        _errorMessage = 'No token found. Please log in.';
        return;
      }

      // Decrypt the token
      final token = _decrypt(encryptedToken);

      // Fetch markets from the API
      final response = await http.get(
        Uri.parse('$_baseMarketUrl'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('Markets response: ${response.body}');

      if (response.statusCode == 200) {
        _markets = json.decode(response.body);
        _errorMessage = null;
      } else {
        _errorMessage = 'Failed to fetch markets.';
      }
    } catch (e) {
      _errorMessage = 'An error occurred. Please try again.';
      print('Error fetching markets: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    // Read the encrypted token from SharedPreferences
    final encryptedToken = _prefs.getString('token');
    if (encryptedToken != null) {
      // Decrypt the token
      final token = _decrypt(encryptedToken);
      // Fetch markets if the token is valid
      await fetchMarkets();
      await fetchProfile();
    }
  }

  Future<void> fetchProfile() async {
    if (_userId == null) {
      print('User ID is null. Cannot fetch profile.');
      return;
    }

    final response = await http.get(
      Uri.parse('$_baseAuthUrl/profile/$_userId'),
      headers: {
        'Authorization': 'Bearer ${await getToken()}',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _userProfile = data['data']['profile'];
      notifyListeners();
    } else {
      print('Failed to fetch profile: ${response.body}');
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? profilePicture,
  }) async {
    final url = Uri.parse('$_baseAuthUrl/profile/$_userId');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${await getToken()}',
    };

    final body = json.encode({
      'firstName': firstName,
      'lastName': lastName,
      'birthDate': birthDate?.toUtc().toIso8601String(),
    });

    try {
      final response = await http.put(url, headers: headers, body: body);

      print(userId); // Debugging
      print('Response status: ${response.statusCode}'); // Debugging
      print('Edit Body: ${body}'); // Debugging

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _userProfile = responseData['data']['profile'];

        notifyListeners();
      } else if (response.statusCode == 404) {
        throw Exception('User not found');
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (error) {
      throw Exception('Failed to update profile: $error');
    }
  }

  Future<void> updateLot({
    required String marketId,
    required String lotId,
    required String name,
    required String details,
    required double price,
    required bool available,
    required Size size,
    required Offset position,
  }) async {
    final token = await getToken(); // Ensure this is used

    if (token == null) {
      throw Exception('No token found. Please log in.');
    }

    final url = Uri.parse('http://localhost:3002/lots/$lotId');
    final headers = {
      'Authorization': 'Bearer $token', // Use the token here
      'Content-Type': 'application/json',
    };

    final body = json.encode({
      'name': name,
      'details': details,
      'price': price,
      'available': available,
      'shape': {
        'width': size.width,
        'height': size.height,
      },
      'position': {
        'x': position.dx,
        'y': position.dy,
      },
    });

    try {
      final response = await http.put(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        // Notify listeners or update local state if needed
        notifyListeners();
      } else {
        throw Exception('Failed to update lot: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to update lot: $e');
    }
  }
}
