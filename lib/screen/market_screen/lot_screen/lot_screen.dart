import 'package:flutter/material.dart';
import 'package:market_lot_app/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MarketLayoutScreen extends StatefulWidget {
  final String marketId;

  MarketLayoutScreen({required this.marketId});

  @override
  _MarketLayoutScreenState createState() => _MarketLayoutScreenState();
}

class _MarketLayoutScreenState extends State<MarketLayoutScreen> {
  List<Map<String, dynamic>> lots = [];

  @override
  void initState() {
    super.initState();
    _fetchLots();
  }

  Future<void> _fetchLots() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    final url =
        Uri.parse('http://localhost:3002/markets/${widget.marketId}/lots');
    final headers = {
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          lots = data.map((lot) {
            return {
              'id': lot['id'],
              'name': lot['name'],
              'details': lot['details'],
              'price': lot['price'],
              'available': lot['available'],
              'position': Offset(lot['position']['x'], lot['position']['y']),
              'size': Size(lot['shape']['width'], lot['shape']['height']),
            };
          }).toList();
        });
      } else {
        throw Exception('Failed to fetch lots');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch lots: $e')),
      );

      print(e); //Debugging
    }
  }

  void _addLot() {
    setState(() {
      lots.add({
        'id': 'new-lot-${lots.length + 1}', // Temporary ID for new lots
        'name': 'New Lot',
        'details': 'Custom lot',
        'price': 100,
        'available': true,
        'position': Offset(0, 0),
        'size': Size(100, 100),
      });
    });
  }

  void _updateLotPosition(int index, Offset position) {
    setState(() {
      lots[index]['position'] = position;
    });
  }

  Future<void> _saveLots() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    final url =
        Uri.parse('http://localhost:3002/markets/${widget.marketId}/lots');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      for (var lot in lots) {
        final body = json.encode({
          'name': lot['name'],
          'details': lot['details'],
          'price': lot['price'],
          'available': lot['available'],
          'shape': {
            'width': lot['size'].width,
            'height': lot['size'].height,
          },
          'position': {
            'x': lot['position'].dx,
            'y': lot['position'].dy,
          },
        });

        if (lot['id'].toString().startsWith('new-lot')) {
          // Create new lot
          await http.post(url, headers: headers, body: body);
        } else {
          // Update existing lot
          await http.put(
            Uri.parse('$url/${lot['id']}'),
            headers: headers,
            body: body,
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lots saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save lots: $e')),
      );
    }
  }

  void _showLotDetails(Map<String, dynamic> lot) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(lot['name']),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Details: ${lot['details']}'),
              Text('Price: \$${lot['price']}'),
              Text(
                  'Availability: ${lot['available'] ? 'Available' : 'Not Available'}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _editLot(int index) {
    showDialog(
      context: context,
      builder: (context) {
        final lot = lots[index];
        TextEditingController nameController =
            TextEditingController(text: lot['name']);
        TextEditingController detailsController =
            TextEditingController(text: lot['details']);
        TextEditingController priceController =
            TextEditingController(text: lot['price'].toString());

        return AlertDialog(
          title: Text('Edit Lot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: detailsController,
                decoration: InputDecoration(labelText: 'Details'),
              ),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  lots[index]['name'] = nameController.text;
                  lots[index]['details'] = detailsController.text;
                  lots[index]['price'] = double.parse(priceController.text);
                });
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLandlord = authProvider.userRole == 'LANDLORD';

    return Scaffold(
      appBar: AppBar(
        title: Text('Market Layout'),
        actions: isLandlord
            ? [
                IconButton(
                  icon: Icon(Icons.save),
                  onPressed: _saveLots,
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          // Market Layout Background (You can replace this with an actual image or design)
          Container(
            color: Colors.grey[200],
          ),
          // Draggable Lots
          for (var i = 0; i < lots.length; i++)
            Positioned(
              left: lots[i]['position'].dx,
              top: lots[i]['position'].dy,
              child: GestureDetector(
                onTap: () {
                  if (!isLandlord) {
                    _showLotDetails(lots[i]);
                  }
                },
                onLongPress: () {
                  if (isLandlord) {
                    _editLot(i);
                  }
                },
                onPanUpdate: isLandlord
                    ? (details) {
                        setState(() {
                          lots[i]['position'] += details.delta;
                        });
                      }
                    : null,
                child: Container(
                  width: lots[i]['size'].width,
                  height: lots[i]['size'].height,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.5),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Center(
                    child: Text(
                      lots[i]['name'],
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isLandlord
          ? FloatingActionButton(
              onPressed: _addLot,
              child: Icon(Icons.add),
            )
          : null,
    );
  }
}
