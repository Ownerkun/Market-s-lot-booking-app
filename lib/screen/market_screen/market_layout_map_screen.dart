import 'package:flutter/material.dart';
import 'package:market_lot_app/auth_provider.dart';
import 'package:market_lot_app/screen/market_screen/lot_screen/lot_details_screen.dart';
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
  bool _isListView = false; // Toggle between list view and layout view

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

    // Updated URL with marketId as a query parameter
    final url =
        Uri.parse('http://localhost:3002/lots?marketId=${widget.marketId}');
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
        });
      } else {
        throw Exception('Failed to fetch lots');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch lots: $e')),
      );
    }
  }

  Future<void> _addLot() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    // Updated URL for adding a lot
    final url = Uri.parse('http://localhost:3002/lots');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

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
        'x': 0,
        'y': 0,
      },
      'marketId': widget.marketId,
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(newLot),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String lotId =
            responseData['id']; // Get the actual lotId from the API response

        setState(() {
          lots.add({
            'id': lotId, // Use the actual lotId
            'name': newLot['name'],
            'details': newLot['details'],
            'price': newLot['price'],
            'available': newLot['available'],
            'position': Offset(0, 0),
            'size': Size(100, 100),
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lot added successfully!')),
        );
      } else {
        print('Failed to fetch lots. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to add lot: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add lot: $e')),
      );
    }
  }

  Future<void> _saveLots(Map<String, dynamic> lot) async {
    if (lot['id'].toString().startsWith('new-lot')) {
      // Skip saving if the lot is new (not yet saved to the database)
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

    // Updated URL for updating a lot
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
        'marketId': widget.marketId, // Include marketId in the request body
      });

      final response = await http.put(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lot saved successfully!')),
        );
      } else {
        throw Exception('Failed to save lot: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save lot: $e')),
      );
    }
  }

  void _editLot(BuildContext context, int index) async {
    final lot = lots[index];
    TextEditingController nameController =
        TextEditingController(text: lot['name']);
    TextEditingController detailsController =
        TextEditingController(text: lot['details']);
    TextEditingController priceController =
        TextEditingController(text: lot['price'].toString());

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) {
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
              onPressed: () async {
                try {
                  await authProvider.updateLot(
                    marketId: widget.marketId,
                    lotId: lot['id'],
                    name: nameController.text,
                    details: detailsController.text,
                    price: double.parse(priceController.text),
                    available: lot['available'],
                    size: lot['size'],
                    position: lot['position'],
                  );

                  setState(() {
                    lots[index]['name'] = nameController.text;
                    lots[index]['details'] = detailsController.text;
                    lots[index]['price'] = double.parse(priceController.text);
                  });

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update lot: $e')),
                  );
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditLotBottomSheet(BuildContext context, int index) async {
    final lot = lots[index];
    TextEditingController nameController =
        TextEditingController(text: lot['name']);
    TextEditingController detailsController =
        TextEditingController(text: lot['details']);
    TextEditingController priceController =
        TextEditingController(text: lot['price'].toString());

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit Lot',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
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
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await authProvider.updateLot(
                            marketId: widget.marketId,
                            lotId: lot['id'],
                            name: nameController.text,
                            details: detailsController.text,
                            price: double.parse(priceController.text),
                            available: lot['available'],
                            size: lot['size'],
                            position: lot['position'],
                          );

                          setState(() {
                            lots[index]['name'] = nameController.text;
                            lots[index]['details'] = detailsController.text;
                            lots[index]['price'] =
                                double.parse(priceController.text);
                          });

                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update lot: $e')),
                          );
                        }
                      },
                      child: Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
        actions: [
          IconButton(
            icon: Icon(_isListView ? Icons.map : Icons.list),
            onPressed: () {
              setState(() {
                _isListView =
                    !_isListView; // Toggle between list and layout view
              });
            },
          ),
          if (_isListView && isLandlord)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: _addLot,
            ),
        ],
      ),
      body: _isListView
          ? _buildListView(isLandlord)
          : _buildLayoutView(isLandlord),
      floatingActionButton: isLandlord && !_isListView
          ? FloatingActionButton(
              onPressed: _addLot,
              child: Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildListView(bool isLandlord) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: lots.length,
      itemBuilder: (context, index) {
        final lot = lots[index];
        final authProvider = Provider.of<AuthProvider>(context,
            listen: false); // Access AuthProvider instance

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text(lot['name']),
            subtitle: Text('Price: \$${lot['price']}'),
            trailing: IconButton(
              icon: Icon(Icons.info_outline),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LotDetailsScreen(
                      lot: lot,
                      isLandlord: isLandlord,
                      marketId: widget.marketId,
                      onSave: (name, detail, price) async {
                        try {
                          await authProvider.updateLot(
                            // Call updateLot on the instance
                            marketId: widget.marketId,
                            lotId: lot['id'],
                            name: name,
                            details: detail,
                            price: price,
                            available: lot['available'],
                            size: lot['size'],
                            position: lot['position'],
                          );
                          _fetchLots(); // Refresh the list after saving
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update lot: $e')),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LotDetailsScreen(
                    lot: lot,
                    isLandlord: isLandlord,
                    marketId: widget.marketId,
                    onSave: (name, detail, price) async {
                      try {
                        await authProvider.updateLot(
                          // Call updateLot on the instance
                          marketId: widget.marketId,
                          lotId: lot['id'],
                          name: name,
                          details: detail,
                          price: price,
                          available: lot['available'],
                          size: lot['size'],
                          position: lot['position'],
                        );
                        _fetchLots(); // Refresh the list after saving
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update lot: $e')),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLayoutView(bool isLandlord) {
    return Stack(
      children: [
        // Market Layout Background (may replace this with an actual image or design)
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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => LotDetailsScreen(
                          lot: lots[i],
                          isLandlord: isLandlord,
                          marketId: widget.marketId,
                          onSave: (name, details, price) {}),
                    ),
                  );
                }
              },
              onLongPress: () {
                if (isLandlord) {
                  _showEditLotBottomSheet(context, i);
                }
              },
              onPanUpdate: isLandlord
                  ? (details) {
                      setState(() {
                        lots[i]['position'] += details.delta;
                      });
                    }
                  : null,
              onPanEnd: isLandlord
                  ? (details) {
                      // Auto-save when dragging ends
                      _saveLots(lots[i]);
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
    );
  }
}
