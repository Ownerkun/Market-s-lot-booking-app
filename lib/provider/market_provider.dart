import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'dart:math';

class MarketProvider with ChangeNotifier {
  final AuthProvider _authProvider;
  final Map<String, List<Map<String, dynamic>>> _bookings = {};
  List<Map<String, dynamic>> _lots = [];
  bool _isLoading = true;
  Map<String, dynamic>? _marketInfo;
  MarketProvider(this._marketId, this._authProvider);
  String _marketId;

  final Map<String, Set<DateTime>> _lotPendingDates = {};
  String? _errorMessage;

  bool _lotsFetched = false;
  bool get lotsFetched => _lotsFetched;

  // Getters
  List<Map<String, dynamic>> get lots => _lots;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get marketInfo => _marketInfo;
  String get marketId => _marketId;
  String? get errorMessage => _errorMessage;

  // Initialize data
  Future<void> init(BuildContext context) async {
    await fetchMarketInfo(context);
    await fetchLots(context);
  }

  // Fetch market information
  Future<void> fetchMarketInfo(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    final url = Uri.parse('http://localhost:3002/markets/$_marketId');
    final headers = {
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(url, headers: headers);

      // print('Market info response: ${response.body}'); //Debugging
      if (response.statusCode == 200) {
        _marketInfo = json.decode(response.body);
        notifyListeners();
      } else {
        throw Exception('Failed to fetch market info');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch market info: $e')),
      );
    }
  }

  // Fetch lots
  Future<void> fetchLots(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // print('Fetching lots for market $_marketId'); //Debugging
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      _isLoading = false;
      notifyListeners();
      return;
    }

    final url = Uri.parse('http://localhost:3002/lots?marketId=$_marketId');
    final headers = {
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(url, headers: headers);
      // print('Lots response status: ${response.statusCode}'); //Debugging
      // print('Lots response body: ${response.body}'); //Debugging

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _lots = data.map((lot) {
          return {
            'id': lot['id'],
            'name': lot['name'],
            'details': lot['details'],
            'price': lot['price'].toDouble(),
            'available': lot['available'],
            'position': Offset(
              lot['position']['x'].toDouble(),
              lot['position']['y'].toDouble(),
            ),
            'size': Size(
              lot['shape']['width'].toDouble(),
              lot['shape']['height'].toDouble(),
            ),
          };
        }).toList();
        _isLoading = false;
        _lotsFetched = true;
        notifyListeners();
      } else {
        throw Exception('Failed to fetch lots');
      }
    } catch (e) {
      // print('Error fetching lots: $e'); //Debugging
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch lots: $e')),
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new lot
  Future<void> addLot(BuildContext context, {Size? initialSize}) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();

      if (token == null) {
        throw Exception('No token found. Please log in.');
      }

      final size = initialSize ?? const Size(100, 100);
      final screenSize = MediaQuery.of(context).size;

      // Generate random position within visible bounds with padding
      final padding = 20.0;
      final randomX = padding +
          (screenSize.width - size.width - 2 * padding) * Random().nextDouble();
      final randomY = padding +
          (screenSize.height - size.height - 2 * padding) *
              Random().nextDouble();

      final newLot = {
        'name': 'New Lot',
        'details': 'Custom lot',
        'price': 100.0,
        'available': true,
        'shape': {
          'width': size.width,
          'height': size.height,
        },
        'position': {
          'x': randomX,
          'y': randomY,
        },
        'marketId': _marketId,
      };

      final response = await http.post(
        Uri.parse('http://localhost:3002/lots'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(newLot),
      );

      if (response.statusCode != 201) {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }

      final responseData = json.decode(response.body);

      // Add new lot to local state
      _lots.add({
        'id': responseData['id'],
        'name': newLot['name'],
        'details': newLot['details'],
        'price': newLot['price'],
        'available': newLot['available'],
        'position': Offset(randomX, randomY),
        'size': size,
        'marketId': _marketId,
      });

      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Lot added successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error adding lot: $e'); // For debugging
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to add lot: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Save lot position
  Future<void> saveLotPosition(
      BuildContext context, Map<String, dynamic> lot) async {
    if (lot['id'].toString().startsWith('new-lot')) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();

      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.put(
        Uri.parse('http://localhost:3002/lots/${lot['id']}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': lot['name'],
          'details': lot['details'],
          'price': lot['price'],
          'available': lot['available'] ?? false,
          'shape': {
            'width': lot['size'].width,
            'height': lot['size'].height,
          },
          'position': {
            'x': lot['position'].dx,
            'y': lot['position'].dy,
          },
          'marketId': _marketId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }

      // Update local state
      final index = _lots.indexWhere((l) => l['id'] == lot['id']);
      if (index != -1) {
        _lots[index] = lot;
        notifyListeners();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Position saved'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error saving lot position: $e'); // For debugging
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to save position: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> updateLotSize(
      BuildContext context, String lotId, Size newSize) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();

      if (token == null) {
        throw Exception('Authentication required');
      }

      final lotIndex = _lots.indexWhere((lot) => lot['id'] == lotId);
      if (lotIndex == -1) throw Exception('Lot not found');

      final lot = _lots[lotIndex];
      final position = lot['position'] as Offset;

      final response = await http.put(
        Uri.parse('http://localhost:3002/lots/$lotId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': lot['name'],
          'details': lot['details'],
          'price': lot['price'],
          'available': lot['available'] ?? false,
          'shape': {
            'width': newSize.width,
            'height': newSize.height,
          },
          'position': {
            'x': position.dx,
            'y': position.dy,
          },
          'marketId': _marketId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }

      // Update local state
      _lots[lotIndex] = {
        ..._lots[lotIndex],
        'size': newSize,
      };
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Size updated'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error updating lot size: $e'); // For debugging
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to update size: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Update lot details
  Future<bool> updateLot({
    required int index,
    required String name,
    required String details,
    required double price,
    required bool available,
    required Size size, // Add size parameter
    required BuildContext context,
  }) async {
    try {
      final lot = _lots[index];
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Send update request to server
      final url = Uri.parse('http://localhost:3002/lots/${lot['id']}');
      final token = await authProvider.getToken();

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'details': details,
          'price': price,
          'available': available,
          'shape': {
            'width': size.width,
            'height': size.height,
          },
          'position': {
            'x': lot['position'].dx,
            'y': lot['position'].dy,
          },
          'marketId': _marketId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      // Update local data
      _lots[index] = {
        ..._lots[index],
        'name': name,
        'details': details,
        'price': price,
        'available': available,
        'size': size,
      };

      notifyListeners();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lot updated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      return true;
    } catch (e) {
      print('Error updating lot: $e'); // For debugging
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update lot: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return false;
    }
  }

  // Update lot position in local state (for dragging)
  void updateLotPosition(int index, Offset delta) {
    if (index < 0 || index >= lots.length) return;

    final lot = lots[index];
    final newPosition = lot['position'] + delta;

    // Update the lot position
    lots[index] = {
      ...lot,
      'position': newPosition,
    };

    notifyListeners();
  }

  Future<bool> requestBooking(
    BuildContext context,
    String lotId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();

      if (token == null) {
        throw Exception('Authentication required');
      }

      final url = Uri.parse('http://localhost:3002/bookings');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final formattedStartDate = startDate.toIso8601String();
      final formattedEndDate = endDate.toIso8601String();

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({
          'lotId': lotId,
          'startDate': formattedStartDate,
          'endDate': formattedEndDate,
          'marketId': _marketId,
        }),
      );

      if (response.statusCode == 201) {
        // Update local pending dates
        final datesInRange = _getDatesInRange(startDate, endDate);
        _lotPendingDates.update(
          lotId,
          (dates) => dates..addAll(datesInRange),
          ifAbsent: () => datesInRange,
        );

        notifyListeners();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Booking request sent successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        _errorMessage = null;
        await loadBookingsForLot(lotId);
        return true;
      } else {
        final error = json.decode(response.body)['message'] ??
            'Failed to request booking';
        throw Exception(error);
      }
    } catch (e) {
      _errorMessage = e.toString();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Booking request failed: $_errorMessage')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return false;
    }
  }

  // Helper method to get dates in range
  Set<DateTime> _getDatesInRange(DateTime start, DateTime end) {
    final dates = <DateTime>{};
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDate)) {
      dates.add(current);
      current = current.add(Duration(days: 1));
    }

    return dates;
  }

  // Method to check if a date is pending for a lot
  bool isDatePending(String lotId, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _lotPendingDates[lotId]?.contains(normalizedDate) ?? false;
  }

  bool isDatePendingForUser(String lotId, DateTime date) {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final pendingDates = _lotPendingDates[lotId];

      if (pendingDates == null || !pendingDates.contains(normalizedDate)) {
        return false;
      }

      final currentUserId = _authProvider.userId;
      if (currentUserId == null) return false;

      return (_bookings[lotId] ?? []).any((booking) => _isUsersPendingBooking(
          booking, lotId, normalizedDate, currentUserId));
    } catch (e) {
      print('Error checking pending date for user: $e');
      return false;
    }
  }

  bool _isUsersPendingBooking(
    Map<String, dynamic> booking,
    String lotId,
    DateTime date,
    String currentUserId,
  ) {
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
  }

  // Clear pending dates for a lot
  void clearPendingDates(String lotId) {
    _lotPendingDates.remove(lotId);
    notifyListeners();
  }

  // Add this method to load bookings for a lot
  Future<void> loadBookingsForLot(String lotId) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Authentication required');

      final response = await http.get(
        Uri.parse('http://localhost:3002/bookings?lotId=$lotId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _bookings[lotId] = List<Map<String, dynamic>>.from(data);
        notifyListeners();
      } else {
        throw Exception('Failed to load bookings');
      }
    } catch (e) {
      print('Error loading bookings: $e'); // For debugging
      _bookings[lotId] = [];
    }
  }

  // Add this method to clear bookings for a lot
  void clearBookings(String lotId) {
    _bookings.remove(lotId);
    notifyListeners();
  }

  bool isDateAvailable(String lotId, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final bookingsForLot = _bookings[lotId] ?? [];

    return !bookingsForLot.any((booking) {
      try {
        // Validate booking data
        if (booking == null ||
            !booking.containsKey('startDate') ||
            !booking.containsKey('endDate') ||
            !booking.containsKey('status')) {
          return false;
        }

        // Parse dates
        final startDate = DateTime.tryParse(booking['startDate']);
        final endDate = DateTime.tryParse(booking['endDate']);
        if (startDate == null || endDate == null) return false;

        // Normalize dates for comparison
        final normalizedStart =
            DateTime(startDate.year, startDate.month, startDate.day);
        final normalizedEnd =
            DateTime(endDate.year, endDate.month, endDate.day);

        return !normalizedDate.isBefore(normalizedStart) &&
            !normalizedDate.isAfter(normalizedEnd) &&
            booking['status'] == 'APPROVED';
      } catch (e) {
        print('Error checking booking availability: $e');
        return false;
      }
    });
  }

  Future<void> loadBookedDatesForLot(String lotId, DateTime date) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Authentication required');

      final formattedDate = date.toIso8601String();
      final url =
          Uri.parse('http://localhost:3002/bookings').replace(queryParameters: {
        'lotId': lotId,
        'date': formattedDate,
      });

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _bookings[lotId] = List<Map<String, dynamic>>.from(data);
        notifyListeners();
      } else {
        throw Exception('Failed to load bookings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading bookings: $e');
      _bookings[lotId] = [];
      rethrow;
    }
  }

  void setState(Function fn) {
    fn();
    notifyListeners();
  }

  Future<void> createMarket({
    required String name,
    required String location,
    required LatLng position,
    required List<String> tagIds,
    required BuildContext context,
  }) async {
    setState(() => _isLoading = true);

    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('No token found. Please log in.');

      final response = await http.post(
        Uri.parse('http://localhost:3002/markets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'location': location,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'tagIds': tagIds,
        }),
      );

      if (response.statusCode != 201) {
        final error =
            json.decode(response.body)['message'] ?? 'Failed to create market';
        throw Exception(error);
      }

      await _authProvider.fetchMarkets();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Market created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create market: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    } finally {
      if (context.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchMarketTags() async {
    try {
      final token = await _authProvider.getToken();
      final response = await http.get(
        Uri.parse('http://localhost:3002/market-tags'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      print('Error fetching tags: $e');
      return [];
    }
  }

  Future<void> createTag(String tagName) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Authentication required');

      final response = await http.post(
        Uri.parse('http://localhost:3002/market-tags'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': tagName,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create tag');
      }
    } catch (e) {
      print('Error creating tag: $e');
      rethrow;
    }
  }
}
