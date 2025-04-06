import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BookingProvider with ChangeNotifier {
  AuthProvider _authProvider;

  final String _baseUrl = "http://localhost:3002/bookings";
  final String _lotBaseUrl = "http://localhost:3002/lots";
  bool _isLoading = false;
  List<dynamic> _bookings = [];
  String? _errorMessage;
  Map<String, List<DateTime>> _lotBookedDates = {};

  BookingProvider(this._authProvider);

  // Add update method
  BookingProvider update(AuthProvider authProvider) {
    _authProvider = authProvider;

    // Clear cached data when auth changes
    _bookings = [];
    _lotBookedDates = {};
    _lotPendingDates = {};
    _errorMessage = null;
    _isLoading = false;

    // Notify listeners of state change
    notifyListeners();
    return this;
  }

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
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final url = marketId != null
          ? Uri.parse('$_baseUrl/landlord?marketId=$marketId')
          : Uri.parse('$_baseUrl/landlord');

      print('Fetching bookings from: ${url.toString()}'); // Debug URL

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}'); // Debug status code

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        print(
            'Raw response: ${json.encode(responseBody)}'); // Debug raw response

        if (responseBody is! List) {
          throw Exception(
              'Invalid response format: expected array, got ${responseBody.runtimeType}');
        }

        // Validate and transform booking data
        _bookings = responseBody.map((booking) {
          if (booking['lot'] == null) {
            print(
                'Warning: Booking without lot information found: ${booking['id']}');
          }
          return booking;
        }).toList();

        _errorMessage = null;
        print('Successfully loaded ${_bookings.length} bookings');
      } else if (response.statusCode == 401) {
        print('Authentication failed: Token expired or invalid');
        await _authProvider.logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        throw Exception(
            'Failed to load bookings: ${response.statusCode}\n${response.body}');
      }
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to fetch bookings: ${e.toString()}';
      print('Error in fetchLandlordBookings: $e');
      print('Stack trace: $stackTrace');
      rethrow;
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

  Future<bool> requestBooking(
    String lotId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _isLoading = true;
    notifyListeners();

    final token = await _authProvider.getToken();
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
      final formattedStartDate = DateTime.utc(
        startDate.year,
        startDate.month,
        startDate.day,
        12, // noon UTC
      ).toIso8601String();

      final formattedEndDate = DateTime.utc(
        endDate.year,
        endDate.month,
        endDate.day,
        12, // noon UTC
      ).toIso8601String();

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'lotId': lotId,
          'startDate': formattedStartDate,
          'endDate': formattedEndDate,
        }),
      );

      if (response.statusCode == 201) {
        // Parse the response to get the booking details
        final booking = json.decode(response.body);
        final bookedStartDate = DateTime.parse(booking['startDate']);
        final bookedEndDate = DateTime.parse(booking['endDate']);

        // Cache all dates in the range as booked
        final datesInRange = _getDatesInRange(bookedStartDate, bookedEndDate);
        if (_lotBookedDates.containsKey(lotId)) {
          _lotBookedDates[lotId]!.addAll(datesInRange);
        } else {
          _lotBookedDates[lotId] = datesInRange;
        }

        _errorMessage = null;
        return true;
      } else if (response.statusCode == 401) {
        _errorMessage = 'Session expired. Please log in again.';
        await _authProvider.logout();
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

  List<DateTime> _getDatesInRange(DateTime startDate, DateTime endDate) {
    final dates = <DateTime>[];
    var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
      dates.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return dates;
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

  Future<bool> updateBookingStatus(String bookingId, String status,
      {String? marketId, String? reason}) async {
    _isLoading = true;
    notifyListeners();

    final token = await _authProvider.getToken();
    if (token == null) {
      _errorMessage = 'No token found. Please log in.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      // Different endpoint for cancellation
      final url = status == 'CANCELLED'
          ? Uri.parse('$_baseUrl/$bookingId/cancel')
          : Uri.parse('$_baseUrl/$bookingId/status');

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.put(
        url,
        headers: headers,
        body: status == 'CANCELLED' ? null : jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        // Find the affected booking
        final booking = _bookings.firstWhere(
          (b) => b['id'] == bookingId,
          orElse: () => null,
        );

        // Refresh data based on status
        if (booking != null && booking['lot'] != null) {
          final lotId = booking['lot']['id'];
          final currentMonth = DateTime.now();

          // For all status changes, refresh availability
          await Future.wait([
            fetchLotAvailabilityForMonth(
                lotId, currentMonth.month, currentMonth.year),
            loadPendingDatesForLot(lotId, currentMonth),
          ]);

          // Refresh bookings list with market context if available
          if (marketId != null) {
            await fetchLandlordBookings(marketId: marketId);
          } else {
            await fetchLandlordBookings();
          }
        }

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

  Future<void> _updateLotAvailability(
    String lotId,
    DateTime startDate,
    DateTime endDate,
    bool available,
    String token,
  ) async {
    final url = Uri.parse('$_lotBaseUrl/$lotId/availability');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // Create date range
    final dates = _getDatesInRange(startDate, endDate);

    for (final date in dates) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);

      await http.put(
        url,
        headers: headers,
        body: jsonEncode({
          'date': formattedDate,
          'available': available,
        }),
      );
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
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final pendingDates = _lotPendingDates[lotId];

    if (pendingDates == null) return false;

    return pendingDates.any((pendingDate) =>
        pendingDate.year == normalizedDate.year &&
        pendingDate.month == normalizedDate.month &&
        pendingDate.day == normalizedDate.day);
  }

  bool isDatePendingForCurrentUser(String lotId, DateTime date) {
    final currentUserId = _authProvider.userId;
    if (currentUserId == null) return false;

    final normalizedDate = DateTime(date.year, date.month, date.day);

    return _bookings.any((booking) =>
        _isUsersPendingBooking(booking, lotId, normalizedDate, currentUserId));
  }

  bool _isUsersPendingBooking(
    Map<String, dynamic> booking,
    String lotId,
    DateTime date,
    String currentUserId,
  ) {
    try {
      if (!booking.containsKey('startDate') ||
          !booking.containsKey('endDate') ||
          !booking.containsKey('status') ||
          !booking.containsKey('tenant')) {
        return false;
      }

      final startDate = DateTime.tryParse(booking['startDate']);
      final endDate = DateTime.tryParse(booking['endDate']);
      if (startDate == null || endDate == null) return false;

      final normalizedStart =
          DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

      return !date.isBefore(normalizedStart) &&
          !date.isAfter(normalizedEnd) &&
          booking['tenant']['id'] == currentUserId &&
          booking['status'] == 'PENDING';
    } catch (e) {
      print('Error checking user pending booking: $e');
      return false;
    }
  }

  Future<void> refreshLotAvailability(String lotId, {String? marketId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      await Future.wait([
        fetchLotAvailabilityForMonth(lotId, now.month, now.year),
        loadPendingDatesForLot(lotId, now),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
