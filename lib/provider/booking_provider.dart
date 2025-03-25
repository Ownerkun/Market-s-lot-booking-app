import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:market_lot_app/provider/auth_provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BookingProvider with ChangeNotifier {
  final AuthProvider _authProvider;
  BookingProvider(this._authProvider);

  final String _baseUrl = "http://localhost:3002/bookings";
  final String _lotBaseUrl = "http://localhost:3002/lots";
  bool _isLoading = false;
  List<dynamic> _bookings = [];
  String? _errorMessage;
  Map<String, List<DateTime>> _lotBookedDates = {};

  // Getters
  bool get isLoading => _isLoading;
  List<dynamic> get bookings => _bookings;
  String? get errorMessage => _errorMessage;
  Map<String, List<DateTime>> get lotBookedDates => _lotBookedDates;

  // Fetch bookings for a landlord
  Future<void> fetchLandlordBookings({String? marketId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('No auth token');

      final url = marketId != null
          ? Uri.parse('$_baseUrl/landlord?marketId=$marketId')
          : Uri.parse('$_baseUrl/landlord');

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is! List) throw Exception('Invalid response format');
        _bookings = data;
      } else {
        throw Exception('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow; // Important to propagate the error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch bookings for a tenant
  Future<void> fetchTenantBookings() async {
    _isLoading = true;
    notifyListeners();

    final token = await _authProvider.getToken(); // Use decrypted token

    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    final url = Uri.parse('$_baseUrl/tenant');
    final headers = {
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        _bookings = json.decode(response.body);
        _errorMessage = null;
      } else if (response.statusCode == 401) {
        _errorMessage = 'Session expired. Please log in again.';
        await _authProvider.logout(); // Log out if token is invalid
      } else {
        _errorMessage = 'Failed to fetch bookings: ${response.body}';
      }
    } catch (e) {
      _errorMessage = 'Failed to fetch bookings: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> fetchLotAvailabilityForMonth(
      String lotId, int month, int year) async {
    _isLoading = true;
    notifyListeners();

    final token = await _authProvider.getToken(); // Use decrypted token

    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return {
        'available': true,
        'bookedDates': []
      }; // Default to available if no token
    }

    final url = Uri.parse(
        '$_baseUrl/lots/$lotId/availability-month?month=$month&year=$year');
    final headers = {
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // print("API Response for lot $lotId: ${response.body}");

        // Convert string dates to DateTime objects
        List<DateTime> bookedDates = [];

        if (data['bookedDates'] != null) {
          bookedDates = (data['bookedDates'] as List)
              .map((dateStr) => DateTime.parse(dateStr))
              .toList();
        }

        // Cache the booked dates
        _lotBookedDates[lotId] = bookedDates;

        _errorMessage = null;
        _isLoading = false;
        notifyListeners();

        // If the API doesn't return an 'available' flag, we'll default to true
        if (!data.containsKey('available')) {
          data['available'] = true;
        }

        return data;
      } else if (response.statusCode == 401) {
        _errorMessage = 'Session expired. Please log in again.';
        await _authProvider.logout(); // Log out if token is invalid
        return {'available': true, 'bookedDates': []};
      } else {
        _errorMessage = 'Failed to fetch availability: ${response.body}';
        _isLoading = false;
        notifyListeners();
        return {'available': true, 'bookedDates': []};
      }
    } catch (e) {
      _errorMessage = 'Failed to fetch availability: $e';
      _isLoading = false;
      notifyListeners();
      return {'available': true, 'bookedDates': []};
    }
  }

  Future<bool> requestBooking(String lotId, DateTime date) async {
    _isLoading = true;
    notifyListeners();

    final token = await _authProvider.getToken(); // Use decrypted token

    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final url = Uri.parse('$_baseUrl');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      // Create a UTC DateTime with complete ISO format
      final formattedDate = DateTime.utc(
        date.year,
        date.month,
        date.day,
        12, // noon UTC
        0,
        0,
      ).toIso8601String(); // Add UTC timezone indicator

      // print('Formatted date: $formattedDate'); // Debug log

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'lotId': lotId,
          'date': formattedDate,
        }),
      );

      if (response.statusCode == 201) {
        if (_lotBookedDates.containsKey(lotId)) {
          _lotBookedDates[lotId]!.add(date);
        } else {
          _lotBookedDates[lotId] = [date];
        }
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        _errorMessage = 'Session expired. Please log in again.';
        await _authProvider.logout(); // Log out if token is invalid
        return false;
      } else {
        _errorMessage = 'Failed to create booking: ${response.body}';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to create booking: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<DateTime> getBookedDatesForLot(String lotId) {
    return _lotBookedDates[lotId] ?? [];
  }

  Future<void> loadBookedDatesForLot(String lotId, DateTime month) async {
    _isLoading = true;
    notifyListeners();

    final token = await _authProvider.getToken();
    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      await Future.wait([
        fetchLotAvailabilityForMonth(lotId, month.month, month.year),
        loadPendingDatesForLot(lotId, month),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add method to check if a specific date is available
  bool isDateAvailable(String lotId, DateTime date) {
    final bookedDates = _lotBookedDates[lotId] ?? [];
    return !bookedDates.any((bookedDate) =>
        bookedDate.year == date.year &&
        bookedDate.month == date.month &&
        bookedDate.day == date.day);
  }

  Future<bool> updateBookingStatus(String bookingId, String status) async {
    _isLoading = true;
    notifyListeners();

    final token = await _authProvider.getToken();
    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final url = Uri.parse('$_baseUrl/$bookingId/status');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode({
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        await fetchLandlordBookings();
        _errorMessage = null;
        return true;
      } else if (response.statusCode == 401) {
        _errorMessage = 'Session expired. Please log in again.';
        await _authProvider.logout();
        return false;
      } else {
        _errorMessage = 'Failed to update booking status: ${response.body}';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to update booking status: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add to BookingProvider class
  Map<String, List<DateTime>> _lotPendingDates = {};

  Future<void> loadPendingDatesForLot(String lotId, DateTime month) async {
    _isLoading = true;
    notifyListeners();

    final token = await _authProvider.getToken();
    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final url = Uri.parse(
          '$_baseUrl/lots/$lotId/pending-dates?month=${month.month}&year=${month.year}');
      final headers = {
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _lotPendingDates[lotId] = (data['pendingDates'] as List)
            .map((dateStr) => DateTime.parse(dateStr))
            .toList();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool isDatePending(String lotId, DateTime date) {
    final pendingDates = _lotPendingDates[lotId] ?? [];
    return pendingDates.any((pendingDate) =>
        pendingDate.year == date.year &&
        pendingDate.month == date.month &&
        pendingDate.day == date.day);
  }
}
