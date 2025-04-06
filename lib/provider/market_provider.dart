import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'dart:math';

class MarketProvider with ChangeNotifier {
  List<Map<String, dynamic>> _lots = [];
  bool _isLoading = true;
  Map<String, dynamic>? _marketInfo;
  MarketProvider(this._marketId);
  String _marketId;

  // Getters
  List<Map<String, dynamic>> get lots => _lots;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get marketInfo => _marketInfo;
  String get marketId => _marketId;

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
}
