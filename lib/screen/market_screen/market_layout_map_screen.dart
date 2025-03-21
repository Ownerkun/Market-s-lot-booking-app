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

class _MarketLayoutScreenState extends State<MarketLayoutScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> lots = [];
  bool _isListView = false;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Map<String, dynamic>? _marketInfo;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _fetchMarketInfo();
    _fetchLots();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchMarketInfo() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    final url = Uri.parse('http://localhost:3002/markets/${widget.marketId}');
    final headers = {
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        setState(() {
          _marketInfo = json.decode(response.body);
        });
      } else {
        throw Exception('Failed to fetch market info');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch market info: $e')),
      );
    }
  }

  Future<void> _fetchLots() async {
    setState(() {
      _isLoading = true;
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No token found. Please log in.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

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
          _isLoading = false;
        });
        _animationController.forward();
      } else {
        throw Exception('Failed to fetch lots');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch lots: $e')),
      );
      setState(() {
        _isLoading = false;
      });
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

    final url = Uri.parse('http://localhost:3002/lots');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // Generate a random x,y position within visible bounds
    final screenSize = MediaQuery.of(context).size;
    final randomX = (MediaQuery.of(context).size.width / 2) *
        (0.2 + 0.6 * (DateTime.now().millisecond / 999));
    final randomY = (MediaQuery.of(context).size.height / 2) *
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
        final String lotId = responseData['id'];

        setState(() {
          lots.add({
            'id': lotId,
            'name': newLot['name'],
            'details': newLot['details'],
            'price': newLot['price'],
            'available': newLot['available'],
            'position': Offset(randomX, randomY),
            'size': Size(100, 100),
          });
        });

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

  Future<void> _saveLots(Map<String, dynamic> lot) async {
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
        'marketId': widget.marketId,
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

  void _showEditLotBottomSheet(BuildContext context, int index) async {
    final lot = lots[index];
    TextEditingController nameController =
        TextEditingController(text: lot['name']);
    TextEditingController detailsController =
        TextEditingController(text: lot['details']);
    TextEditingController priceController =
        TextEditingController(text: lot['price'].toString());
    bool isAvailable = lot['available'] ?? false;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Edit Lot Details',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.edit),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: detailsController,
                    decoration: InputDecoration(
                      labelText: 'Details',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Available for rent:'),
                      Switch(
                        value: isAvailable,
                        onChanged: (value) {
                          setState(() {
                            isAvailable = value;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await authProvider.updateLot(
                              marketId: widget.marketId,
                              lotId: lot['id'],
                              name: nameController.text,
                              details: detailsController.text,
                              price: double.parse(priceController.text),
                              available: isAvailable,
                              size: lot['size'],
                              position: lot['position'],
                            );

                            this.setState(() {
                              lots[index]['name'] = nameController.text;
                              lots[index]['details'] = detailsController.text;
                              lots[index]['price'] =
                                  double.parse(priceController.text);
                              lots[index]['available'] = isAvailable;
                            });

                            Navigator.pop(context);

                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Lot updated successfully'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            print('Error: $e');
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update lot: $e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Color _getLotColor(bool available) {
    return available
        ? Color(0xFF4CAF50).withOpacity(0.7) // Green for available
        : Color(0xFFE57373).withOpacity(0.7); // Red for unavailable
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLandlord = authProvider.userRole == 'LANDLORD';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _marketInfo != null
              ? '${_marketInfo!['name']} Layout'
              : 'Market Layout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFFC0F8C0),
        actions: [
          IconButton(
            icon: Icon(
              _isListView ? Icons.map_outlined : Icons.list,
              color: Colors.black87,
            ),
            onPressed: () {
              setState(() {
                _isListView = !_isListView;
                _animationController.reset();
                _animationController.forward();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading market layout...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: _isListView
                  ? _buildListView(isLandlord)
                  : _buildLayoutView(isLandlord),
            ),
      floatingActionButton: isLandlord
          ? FloatingActionButton.extended(
              onPressed: _addLot,
              label: Text(_isListView ? 'Add Lot' : 'Add Space'),
              icon: Icon(Icons.add),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }

  Widget _buildListView(bool isLandlord) {
    if (lots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.space_dashboard_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No lots available in this market',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            if (isLandlord)
              ElevatedButton.icon(
                onPressed: _addLot,
                icon: Icon(Icons.add),
                label: Text('Add First Lot'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: lots.length,
      itemBuilder: (context, index) {
        final lot = lots[index];
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final isAvailable = lot['available'] ?? false;

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                Container(
                  color: _getLotColor(isAvailable),
                  height: 8,
                ),
                ListTile(
                  contentPadding: EdgeInsets.all(16),
                  title: Row(
                    children: [
                      Text(
                        lot['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              isAvailable ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAvailable ? Colors.green : Colors.red,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isAvailable ? 'Available' : 'Unavailable',
                          style: TextStyle(
                            fontSize: 12,
                            color: isAvailable
                                ? Colors.green[800]
                                : Colors.red[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),
                      Text(
                        lot['details'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.monetization_on,
                              size: 16, color: Colors.amber[700]),
                          SizedBox(width: 4),
                          Text(
                            '\$${lot['price'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.visibility),
                              label: Text('View Details'),
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
                                            marketId: widget.marketId,
                                            lotId: lot['id'],
                                            name: name,
                                            details: detail,
                                            price: price,
                                            available: lot['available'],
                                            size: lot['size'],
                                            position: lot['position'],
                                          );
                                          _fetchLots();
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Failed to update lot: $e')),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue[700],
                                side: BorderSide(color: Colors.blue[300]!),
                              ),
                            ),
                          ),
                          if (isLandlord) ...[
                            SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.edit),
                                label: Text('Edit'),
                                onPressed: () {
                                  _showEditLotBottomSheet(context, index);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayoutView(bool isLandlord) {
    // Create a background grid for better visualization
    return Stack(
      children: [
        // Market Layout Background with grid
        CustomPaint(
          painter: GridPainter(),
          size: Size(MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height),
        ),

        if (lots.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  'No lots available in this market',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                if (isLandlord)
                  ElevatedButton.icon(
                    onPressed: _addLot,
                    icon: Icon(Icons.add),
                    label: Text('Add First Lot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),

        // Draggable Lots
        for (var i = 0; i < lots.length; i++)
          Positioned(
            left: lots[i]['position'].dx,
            top: lots[i]['position'].dy,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LotDetailsScreen(
                      lot: lots[i],
                      isLandlord: isLandlord,
                      marketId: widget.marketId,
                      onSave: (name, details, price) async {
                        try {
                          final authProvider =
                              Provider.of<AuthProvider>(context, listen: false);
                          await authProvider.updateLot(
                            marketId: widget.marketId,
                            lotId: lots[i]['id'],
                            name: name,
                            details: details,
                            price: price,
                            available: lots[i]['available'],
                            size: lots[i]['size'],
                            position: lots[i]['position'],
                          );
                          _fetchLots();
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
              onLongPress: isLandlord
                  ? () {
                      _showEditLotBottomSheet(context, i);
                    }
                  : null,
              onPanUpdate: isLandlord
                  ? (details) {
                      setState(() {
                        lots[i]['position'] += details.delta;
                      });
                    }
                  : null,
              onPanEnd: isLandlord
                  ? (details) {
                      _saveLots(lots[i]);
                    }
                  : null,
              child: LotWidget(
                lot: lots[i],
                isLandlord: isLandlord,
              ),
            ),
          ),

        // Helper text for landlords
        if (isLandlord && lots.isNotEmpty)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Drag to reposition lots • Long press to edit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Grid painter for the background
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw grid lines
    double spacing = 20;

    // Vertical lines
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        gridPaint,
      );
    }

    // Horizontal lines
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Lot widget with improved design
class LotWidget extends StatelessWidget {
  final Map<String, dynamic> lot;
  final bool isLandlord;

  const LotWidget({
    Key? key,
    required this.lot,
    required this.isLandlord,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = lot['available'] ?? false;
    final Color lotColor = isAvailable
        ? Color(0xFF4CAF50).withOpacity(0.7) // Green for available
        : Color(0xFFE57373).withOpacity(0.7); // Red for unavailable

    return Material(
      color: Colors.transparent,
      child: Container(
        width: lot['size'].width,
        height: lot['size'].height,
        decoration: BoxDecoration(
          color: lotColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isAvailable ? Colors.green[800]! : Colors.red[800]!,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            if (isLandlord)
              Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        lot['name'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '\$${lot['price'].toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
