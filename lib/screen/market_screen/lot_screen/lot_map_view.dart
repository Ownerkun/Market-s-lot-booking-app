import 'package:flutter/material.dart';
import 'package:market_lot_app/market_provider.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/auth_provider.dart';
import 'package:market_lot_app/screen/market_screen/lot_screen/lot_details_screen.dart';

class MarketMapView extends StatelessWidget {
  const MarketMapView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketProvider>(
      builder: (context, marketProvider, child) {
        final lots = marketProvider.lots;
        final authProvider = Provider.of<AuthProvider>(context);
        final isLandlord = authProvider.userRole == 'LANDLORD';

        return Stack(
          children: [
            // Market Layout Background with grid
            CustomPaint(
              painter: GridPainter(),
              size: Size(MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height),
            ),

            if (lots.isEmpty)
              _buildEmptyView(context, isLandlord)
            else
              ..._buildLots(context, lots, isLandlord),

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
      },
    );
  }

  Widget _buildEmptyView(BuildContext context, bool isLandlord) {
    final marketProvider = Provider.of<MarketProvider>(context, listen: false);

    return Center(
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
              onPressed: () => marketProvider.addLot(context),
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

  List<Widget> _buildLots(
    BuildContext context,
    List<Map<String, dynamic>> lots,
    bool isLandlord,
  ) {
    final marketProvider = Provider.of<MarketProvider>(context, listen: false);

    return List.generate(lots.length, (i) {
      return Positioned(
        left: lots[i]['position'].dx,
        top: lots[i]['position'].dy,
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LotDetailsScreen(
                  lot: lots[i],
                  isLandlord: isLandlord,
                  marketId: marketProvider.marketId,
                  onSave: (name, details, price) async {
                    try {
                      final authProvider =
                          Provider.of<AuthProvider>(context, listen: false);
                      await authProvider.updateLot(
                        marketId: marketProvider.marketId,
                        lotId: lots[i]['id'],
                        name: name,
                        details: details,
                        price: price,
                        available: lots[i]['available'],
                        size: lots[i]['size'],
                        position: lots[i]['position'],
                      );
                      marketProvider.fetchLots(context);
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
                  marketProvider.updateLotPosition(i, details.delta);
                }
              : null,
          onPanEnd: isLandlord
              ? (details) {
                  marketProvider.saveLotPosition(context, lots[i]);
                }
              : null,
          child: LotWidget(
            lot: lots[i],
            isLandlord: isLandlord,
          ),
        ),
      );
    });
  }

  void _showEditLotBottomSheet(BuildContext context, int index) async {
    final marketProvider = Provider.of<MarketProvider>(context, listen: false);
    final lot = marketProvider.lots[index];

    TextEditingController nameController =
        TextEditingController(text: lot['name']);
    TextEditingController detailsController =
        TextEditingController(text: lot['details']);
    TextEditingController priceController =
        TextEditingController(text: lot['price'].toString());
    bool isAvailable = lot['available'] ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                            final success = await marketProvider.updateLot(
                              index: index,
                              name: nameController.text,
                              details: detailsController.text,
                              price: double.parse(priceController.text),
                              available: isAvailable,
                              context: context,
                            );

                            if (success) {
                              Navigator.pop(context);
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
          },
        );
      },
    );
  }
}

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
