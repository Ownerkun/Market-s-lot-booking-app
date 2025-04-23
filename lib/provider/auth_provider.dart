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
  bool get isAdmin => _userRole == 'ADMIN';

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
    // Delay the notification to avoid build phase conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

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
    } finally {
      _isLoading = false;
      // Delay the notification to avoid build phase conflicts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
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

      print('Response body: ${response.body}'); // Debugging

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

  List<Map<String, dynamic>> _markets = [];
  List<Map<String, dynamic>> get markets => _markets;

  Future<void> fetchMarkets() async {
    // Don't notify immediately to avoid build phase conflicts
    _isLoading = true;

    try {
      final token = await getToken();
      if (token == null) throw Exception('Authentication required');

      final response = await http.get(
        Uri.parse('http://localhost:3002/markets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _markets = (json.decode(response.body) as List)
            .map((market) => market as Map<String, dynamic>)
            .toList();
        _errorMessage = null;
      } else {
        throw Exception('Failed to load markets: ${response.statusCode}');
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      // Safely notify listeners after build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
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

  Future<List<dynamic>> getAllUsers() async {
    _isLoading = true;

    try {
      final token = await getToken();
      if (token == null) throw Exception('Authentication required');

      final response = await http.get(
        Uri.parse('$_baseAuthUrl/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as List<dynamic>;
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<void> deleteUser(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await getToken();
      if (token == null) throw Exception('Authentication required');

      final response = await http.delete(
        Uri.parse('$_baseAuthUrl/user/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete user: ${response.statusCode}');
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> submit({
    required BuildContext context,
    required bool isLogin,
    required String email,
    required String password,
    String? selectedRole,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
  }) async {
    try {
      if (isLogin) {
        await login(email, password);
      } else {
        // Prevent non-admin users from registering as admin
        if (selectedRole == 'ADMIN' && !isAdmin) {
          return {
            'success': false,
            'message': 'You cannot register as an admin'
          };
        }

        if (selectedRole == null) {
          return {'success': false, 'message': 'Please select a role'};
        }

        await register(
          email,
          password,
          selectedRole,
          firstName ?? '',
          lastName ?? '',
          birthDate,
        );
      }

      if (errorMessage == null) {
        return {'success': true, 'message': null};
      } else {
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await getToken();
      if (token == null) throw Exception('Authentication required');

      final response = await http.post(
        Uri.parse('$_baseAuthUrl/change-password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Password changed successfully',
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to change password',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
