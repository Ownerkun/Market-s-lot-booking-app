import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:market_lot_app/auth_provider.dart';

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
    print('Fetching lots for market $_marketId');
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
      print('Lots response status: ${response.statusCode}');
      print('Lots response body: ${response.body}');

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
      print('Error fetching lots: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch lots: $e')),
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new lot
  Future<void> addLot(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    final url = Uri.parse('http://localhost:3002/lots');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // Generate a random x,y position within visible bounds
    final screenSize = MediaQuery.of(context).size;
    final randomX = (screenSize.width / 2) *
        (0.2 + 0.6 * (DateTime.now().millisecond / 999));
    final randomY = (screenSize.height / 2) *
        (0.2 + 0.6 * (DateTime.now().microsecond / 999));

    final newLot = {
      'name': 'New Lot',
      'details': 'Custom lot',
      'price': 100,
      'available': true,
      'shape': {
        'width': 100,
        'height': 100,
      },
      'position': {
        'x': randomX,
        'y': randomY,
      },
      'marketId': _marketId,
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(newLot),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String lotId = responseData['id'];

        _lots.add({
          'id': lotId,
          'name': newLot['name'],
          'details': newLot['details'],
          'price': newLot['price'],
          'available': newLot['available'],
          'position': Offset(randomX, randomY),
          'size': Size(100, 100),
        });

        notifyListeners();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lot added successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('Failed to add lot: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add lot: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Save lot position
  Future<void> saveLotPosition(
      BuildContext context, Map<String, dynamic> lot) async {
    if (lot['id'].toString().startsWith('new-lot')) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    final url = Uri.parse('http://localhost:3002/lots/${lot['id']}');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      final body = json.encode({
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
      });

      final response = await http.put(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lot position saved'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        throw Exception('Failed to save lot: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save lot: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Update lot details
  Future<bool> updateLot({
    required int index,
    required String name,
    required String details,
    required double price,
    required bool available,
    required BuildContext context,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.updateLot(
        marketId: _marketId,
        lotId: _lots[index]['id'],
        name: name,
        details: details,
        price: price,
        available: available,
        size: _lots[index]['size'],
        position: _lots[index]['position'],
      );

      // Update local data
      _lots[index]['name'] = name;
      _lots[index]['details'] = details;
      _lots[index]['price'] = price;
      _lots[index]['available'] = available;

      notifyListeners();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lot updated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update lot: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  // Update lot position in local state (for dragging)
  void updateLotPosition(int index, Offset delta) {
    _lots[index]['position'] += delta;
    notifyListeners();
  }
}
