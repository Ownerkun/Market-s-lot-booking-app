import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LotScreen extends StatefulWidget {
  final String marketId;

  LotScreen({required this.marketId});

  @override
  _LotScreenState createState() => _LotScreenState();
}

class _LotScreenState extends State<LotScreen> {
  List<Lot> lots = [];
  bool isLoading = true;

  Matrix4 _transform = Matrix4.identity();
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;

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

    try {
      final response = await http.get(
        Uri.parse('http://localhost:3002/markets/${widget.marketId}/lots'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          lots = data.map((lot) => Lot.fromJson(lot)).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch lots: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch lots: $e')),
      );
      print(e); // Debugging
    }
  }

  void _onLotTap(Lot lot) {
    if (Provider.of<AuthProvider>(context, listen: false).userRole ==
        'TENANT') {
      // Navigate to details page for tenants
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LotDetailsScreen(lot: lot),
        ),
      );
    }
  }

  void _onLotLongPress(Lot lot) {
    if (Provider.of<AuthProvider>(context, listen: false).userRole ==
        'LANDLORD') {
      // Show edit menu for landlords
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Edit Lot'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Edit Details'),
                  onTap: () {
                    Navigator.pop(context);
                    _editLotDetails(lot);
                  },
                ),
                ListTile(
                  title: Text('Delete Lot'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteLot(lot);
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }

  void _editLotDetails(Lot lot) {
    final nameController = TextEditingController(text: lot.name);
    final detailsController = TextEditingController(text: lot.details);
    final priceController = TextEditingController(text: lot.price.toString());
    final availableController =
        TextEditingController(text: lot.available.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Lot Details'),
          content: SingleChildScrollView(
            child: Column(
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
                TextField(
                  controller: availableController,
                  decoration:
                      InputDecoration(labelText: 'Available (true/false)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final updatedLot = Lot(
                  id: lot.id,
                  name: nameController.text,
                  details: detailsController.text,
                  price: double.parse(priceController.text),
                  available: availableController.text.toLowerCase() == 'true',
                  shape: lot.shape,
                  position: lot.position,
                );

                await _updateLotDetails(updatedLot);
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteLot(Lot lot) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse(
            'http://localhost:3002/markets/${widget.marketId}/lots/${lot.id}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          lots.removeWhere((l) => l.id == lot.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lot deleted successfully!')),
        );
      } else {
        throw Exception('Failed to delete lot: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete lot: $e')),
      );
      print(e); // Debugging
    }
  }

  void _addLot() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3002/markets/${widget.marketId}/lots'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': 'Lot ${lots.length + 1}',
          'details': 'Details about Lot ${lots.length + 1}',
          'price': 100.0,
          'available': true,
          'shape': {'width': 100.0, 'height': 50.0},
          'position': {'x': 0.0, 'y': 0.0}, // Default position
        }),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          lots.add(Lot.fromJson(data)); // Use the ID returned by the backend
        });
      } else {
        throw Exception('Failed to add lot: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add lot: $e')),
      );
      print(e); // Debugging
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandlord =
        Provider.of<AuthProvider>(context).userRole == 'LANDLORD';

    return Scaffold(
      appBar: AppBar(
        title: Text('Market Lots'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : GestureDetector(
              onScaleStart: (details) {
                _startOffset = details.focalPoint;
              },
              onScaleUpdate: (details) {
                setState(() {
                  _scale = details.scale;
                  _offset = details.focalPoint - _startOffset;
                  _transform = Matrix4.identity()
                    ..translate(_offset.dx, _offset.dy)
                    ..scale(_scale);
                });
              },
              onScaleEnd: (details) {
                setState(() {
                  _scale = 1.0;
                  _offset = Offset.zero;
                });
              },
              child: Transform(
                transform: _transform,
                child: Stack(
                  children: [
                    // Canvas Background
                    Container(
                      color: Colors.grey[200],
                    ),
                    // Lots
                    for (final lot in lots)
                      Positioned(
                        left: lot.position['x'],
                        top: lot.position['y'],
                        child: isLandlord
                            ? Draggable(
                                feedback: Material(
                                  child: Container(
                                    width: lot.shape['width'],
                                    height: lot.shape['height'],
                                    color: Colors.blue.withOpacity(0.5),
                                    child: Center(
                                      child: Text(
                                        lot.name,
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                                childWhenDragging:
                                    Container(), // Hide the original lot while dragging
                                child: GestureDetector(
                                  onTap: () => _onLotTap(lot),
                                  onLongPress: () => _onLotLongPress(lot),
                                  child: Container(
                                    width: lot.shape['width'],
                                    height: lot.shape['height'],
                                    color: Colors.blue,
                                    child: Center(
                                      child: Text(
                                        lot.name,
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                                onDragEnd: (details) {
                                  setState(() {
                                    lot.position['x'] = details.offset.dx;
                                    lot.position['y'] = details.offset.dy;
                                  });
                                  // Save the new position to the database
                                  _updateLotPosition(lot);
                                },
                              )
                            : GestureDetector(
                                onTap: () => _onLotTap(lot),
                                child: Container(
                                  width: lot.shape['width'],
                                  height: lot.shape['height'],
                                  color: Colors.blue,
                                  child: Center(
                                    child: Text(
                                      lot.name,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: isLandlord
          ? FloatingActionButton(
              onPressed: _addLot,
              child: Icon(Icons.add, color: Colors.white),
              backgroundColor: Colors.blueAccent,
              elevation: 5,
              tooltip: 'Add Lot',
            )
          : null,
    );
  }

  Future<void> _updateLotDetails(Lot lot) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    try {
      final response = await http.put(
        Uri.parse(
            'http://localhost:3002/markets/${widget.marketId}/lots/${lot.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': lot.name,
          'details': lot.details,
          'price': lot.price,
          'available': lot.available,
          'shape': lot.shape,
          'position': lot.position,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          final index = lots.indexWhere((l) => l.id == lot.id);
          if (index != -1) {
            lots[index] = lot;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lot updated successfully!')),
        );
      } else {
        throw Exception('Failed to update lot: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update lot: $e')),
      );
    }
  }

  Future<void> _updateLotPosition(Lot lot) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    try {
      final response = await http.put(
        Uri.parse(
            'http://localhost:3002/markets/${widget.marketId}/lots/${lot.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'position': lot.position,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lot position updated successfully!')),
        );
      } else {
        throw Exception('Failed to update lot position: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update lot position: $e')),
      );
      print(e); // Debugging
    }
  }
}

class Lot {
  final String id;
  final String name;
  final String details;
  final double price;
  final bool available;
  final Map<String, double> shape;
  final Map<String, double> position;

  Lot({
    required this.id,
    required this.name,
    required this.details,
    required this.price,
    required this.available,
    required this.shape,
    required this.position,
  });

  factory Lot.fromJson(Map<String, dynamic> json) {
    return Lot(
      id: json['id'],
      name: json['name'],
      details: json['details'],
      price: json['price'].toDouble(), // Ensure price is double
      available: json['available'],
      shape: {
        'width': json['shape']['width'].toDouble(), // Convert int to double
        'height': json['shape']['height'].toDouble(), // Convert int to double
      },
      position: {
        'x': json['position']['x'].toDouble(), // Convert int to double
        'y': json['position']['y'].toDouble(), // Convert int to double
      },
    );
  }
}

class LotDetailsScreen extends StatelessWidget {
  final Lot lot;

  LotDetailsScreen({required this.lot});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lot.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Details: ${lot.details}'),
            Text('Price: \$${lot.price}'),
            Text('Available: ${lot.available ? 'Yes' : 'No'}'),
          ],
        ),
      ),
    );
  }
}
