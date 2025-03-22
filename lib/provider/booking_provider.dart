import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BookingProvider with ChangeNotifier {
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
  Future<void> fetchLandlordBookings() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    final url = Uri.parse('$_baseUrl/landlord');
    final headers = {
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        _bookings = json.decode(response.body);
        _errorMessage = null;
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

  // Fetch bookings for a tenant
  Future<void> fetchTenantBookings() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

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

  // Check lot availability for a specific date
  Future<bool> checkLotAvailability(String lotId, DateTime date) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final formattedDate = date.toIso8601String().split('T')[0];
    final url =
        Uri.parse('$_lotBaseUrl/$lotId/availability?date=$formattedDate');
    final headers = {
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return data['available'];
      } else {
        _errorMessage = 'Failed to check availability: ${response.body}';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to check availability: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch booked dates for a lot
  Future<List<DateTime>> fetchLotBookedDates(String lotId) async {
    if (_lotBookedDates.containsKey(lotId)) {
      return _lotBookedDates[lotId]!;
    }

    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return [];
    }

    // Assuming the API has an endpoint to get all bookings for a specific lot
    // This endpoint might need to be created on the backend
    final url = Uri.parse('$_baseUrl?lotId=$lotId');
    final headers = {
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> bookingsData = json.decode(response.body);

        // Extract dates from bookings with status approved or pending
        List<DateTime> bookedDates = bookingsData
            .where((booking) =>
                booking['status'] == 'APPROVED' ||
                booking['status'] == 'PENDING')
            .map<DateTime>((booking) => DateTime.parse(booking['date']))
            .toList();

        _lotBookedDates[lotId] = bookedDates;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return bookedDates;
      } else {
        _errorMessage = 'Failed to fetch booked dates: ${response.body}';
        _isLoading = false;
        notifyListeners();
        return [];
      }
    } catch (e) {
      _errorMessage = 'Failed to fetch booked dates: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // Request a booking (for tenants)
  Future<bool> requestBooking(String lotId, DateTime date) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final url = Uri.parse(_baseUrl);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final body = json.encode({
      'lotId': lotId,
      'date': date.toIso8601String().split('T')[0],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 201) {
        _errorMessage = null;

        // If we have cached dates for this lot, update them
        if (_lotBookedDates.containsKey(lotId)) {
          _lotBookedDates[lotId]!.add(date);
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to request booking: ${response.body}';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to request booking: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update booking status (for landlords)
  Future<void> updateBookingStatus(String bookingId, String status) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    final url = Uri.parse('$_baseUrl/$bookingId/status');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final body = json.encode({
      'status': status,
    });

    try {
      final response = await http.put(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        _errorMessage = null;
        await fetchLandlordBookings(); // Refresh the list

        // Clear cached dates as they may have changed
        _lotBookedDates.clear();
      } else {
        _errorMessage = 'Failed to update booking status: ${response.body}';
      }
    } catch (e) {
      _errorMessage = 'Failed to update booking status: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cancel booking (for tenants)
  Future<bool> cancelBooking(String bookingId) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final url = Uri.parse('$_baseUrl/$bookingId/cancel');
    final headers = {
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.put(url, headers: headers);

      if (response.statusCode == 200) {
        _errorMessage = null;

        // Clear cached dates as they may have changed
        _lotBookedDates.clear();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to cancel booking: ${response.body}';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to cancel booking: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> createBooking({
    required String lotId,
    required DateTime date,
  }) async {
    try {
      // Assuming you have your API base URL defined
      final url = Uri.parse('$_baseUrl/bookings');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // Add any authentication headers if needed
          // 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'lotId': lotId,
          'date': date.toIso8601String(),
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create booking: ${response.body}');
      }

      // Optionally update local state
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }
}
