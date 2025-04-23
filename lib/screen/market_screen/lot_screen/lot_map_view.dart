import 'package:flutter/material.dart';
import 'package:market_lot_app/provider/market_provider.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'package:market_lot_app/screen/market_screen/lot_screen/lot_details_screen.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class MarketMapView extends StatefulWidget {
  const MarketMapView({Key? key}) : super(key: key);

  @override
  _MarketMapViewState createState() => _MarketMapViewState();
}

class _MarketMapViewState extends State<MarketMapView> {
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _previousOffset = Offset.zero;
  Offset _normalizedOffset = Offset.zero;
  bool _isInteractingWithLot = false;

  // Constants for zoom limits
  static const double _minScale = 0.5;
  static const double _maxScale = 3.0;

  // Add date selection state
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _loadInitialData(context);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadInitialData(BuildContext context) async {
    try {
      if (_isDisposed) return;
      setState(() => _isLoading = true);

      final marketProvider =
          Provider.of<MarketProvider>(context, listen: false);
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Load lots if needed
      if (!marketProvider.lotsFetched) {
        await marketProvider.fetchLots(context);
      }

      // Only load bookings if we have lots
      if (!_isDisposed && marketProvider.lots.isNotEmpty) {
        await _refreshAvailability(context);
      }

      // Load tenant bookings if applicable
      if (!_isDisposed && authProvider.userRole == 'TENANT') {
        await bookingProvider.fetchTenantBookings();
      }
    } catch (e) {
      if (_isDisposed) return;
      print('Error loading initial data: $e');

      final scaffold = ScaffoldMessenger.maybeOf(context);
      if (scaffold != null) {
        scaffold.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to load data')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (!_isDisposed) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshAvailability(BuildContext context) async {
    try {
      if (_isDisposed) return;
      setState(() => _isLoading = true);

      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      final marketProvider =
          Provider.of<MarketProvider>(context, listen: false);

      // Only proceed if we have lots
      if (!_isDisposed && marketProvider.lots.isNotEmpty) {
        // Load availability for all lots concurrently
        await Future.wait(
          marketProvider.lots
              .map((lot) => bookingProvider.loadBookedDatesForLot(
                    lot['id'],
                    _selectedDate,
                  )),
        );
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (_isDisposed) return;
      print('Error refreshing availability: $e');

      final scaffold = ScaffoldMessenger.maybeOf(context);
      if (scaffold != null) {
        scaffold.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to load availability')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (!_isDisposed) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketProvider>(
      builder: (context, marketProvider, child) {
        final lots = marketProvider.lots;
        final authProvider = Provider.of<AuthProvider>(context);
        final isLandlord = authProvider.userRole == 'LANDLORD';

        // Early return for loading state
        if (_isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        // Early return for empty state
        if (lots.isEmpty) {
          return _buildEmptyView(context, isLandlord);
        }

        return GestureDetector(
          onScaleStart: (details) {
            _previousScale = _scale;
            _previousOffset = details.focalPoint;
            _isInteractingWithLot = false;
          },
          onScaleUpdate: (details) {
            // Skip if interacting with a lot (for landlords)
            if (isLandlord && _isPositionOverLot(details.focalPoint, lots)) {
              _isInteractingWithLot = true;
              return;
            }

            setState(() {
              // Update scale with bounds
              _scale =
                  (_previousScale * details.scale).clamp(_minScale, _maxScale);

              // Calculate new offset based on focal point
              final newOffset = details.focalPoint - _previousOffset;
              _offset += newOffset;
              _previousOffset = details.focalPoint;

              // Keep content centered by normalizing offset
              _normalizedOffset = _offset / _scale;

              // Enforce boundaries to prevent excessive panning
              final viewSize = MediaQuery.of(context).size;
              final contentSize = Size(viewSize.width * 2, viewSize.height * 2);

              // Calculate bounds
              final maxOffset = Offset(
                contentSize.width * (_scale - 1),
                contentSize.height * (_scale - 1),
              );

              // Clamp offset within bounds
              _offset = Offset(
                _offset.dx.clamp(-maxOffset.dx, maxOffset.dx),
                _offset.dy.clamp(-maxOffset.dy, maxOffset.dy),
              );
            });
          },
          onScaleEnd: (details) {
            _previousScale = _scale;
            _isInteractingWithLot = false;
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: _scale,
                child: Transform.translate(
                  offset: _offset,
                  child: Stack(
                    children: [
                      CustomPaint(
                        painter: GridPainter(),
                        size: Size(
                          MediaQuery.of(context).size.width *
                              4, // Increased grid size
                          MediaQuery.of(context).size.height * 4,
                        ),
                      ),
                      if (lots.isEmpty)
                        _buildEmptyView(context, isLandlord)
                      else
                        ..._buildLots(context, lots, isLandlord),
                    ],
                  ),
                ),
              ),
              _buildControls(isLandlord, lots),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      // Refresh availability for the selected date
      await _refreshAvailability(context);
    }
  }

  Widget _buildControls(bool isLandlord, List<dynamic> lots) {
    return Stack(
      children: [
        // Date picker button
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 18, color: Colors.green),
                SizedBox(width: 8),
                TextButton(
                  onPressed: () => _selectDate(context),
                  child: Text(
                    DateFormat('MMM d, yyyy').format(_selectedDate),
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Reset zoom button
        Positioned(
          bottom: isLandlord ? 80 : 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _resetView,
            child: Icon(Icons.zoom_out_map, color: Colors.green),
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
                  'Pinch to zoom • Long press to edit • Drag to reposition',
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

  bool _isPositionOverLot(Offset position, List<Map<String, dynamic>> lots) {
    // Convert screen position to content position
    final contentPosition = (position - _offset) / _scale;

    return lots.any((lot) {
      final lotRect = Rect.fromLTWH(
        lot['position'].dx,
        lot['position'].dy,
        lot['size'].width,
        lot['size'].height,
      );

      // Add some padding for easier touch detection
      final paddedRect = lotRect.inflate(10.0);
      return paddedRect.contains(contentPosition);
    });
  }

  void _resetView() {
    final viewSize = MediaQuery.of(context).size;
    final contentSize = Size(viewSize.width * 4, viewSize.height * 4);

    setState(() {
      _scale = 1.0;

      // Center the content
      _offset = Offset(
        (contentSize.width - viewSize.width) / -2,
        (contentSize.height - viewSize.height) / -2,
      );

      _normalizedOffset = _offset / _scale;
    });
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
    final viewSize = MediaQuery.of(context).size;
    final maxX = viewSize.width * 4 - 100; // Leave margin for lot width
    final maxY = viewSize.height * 4 - 100; // Leave margin for lot height

    return List.generate(lots.length, (i) {
      return Positioned(
        left: lots[i]['position'].dx,
        top: lots[i]['position'].dy,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LotDetailsScreen(
                  lot: lots[i],
                  isLandlord: isLandlord,
                  marketId: marketProvider.marketId,
                  selectedDate: _selectedDate,
                  onSave: (name, details, price, available) async {
                    try {
                      final authProvider =
                          Provider.of<AuthProvider>(context, listen: false);
                      await authProvider.updateLot(
                        marketId: marketProvider.marketId,
                        lotId: lots[i]['id'],
                        name: name,
                        details: details,
                        price: price,
                        available: available,
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
                  final adjustedDelta = details.delta / _scale;
                  final lot = lots[i];
                  final newPosition = lot['position'] + adjustedDelta;

                  // Apply boundary constraints
                  final boundedPosition = Offset(
                    newPosition.dx.clamp(0.0, maxX),
                    newPosition.dy.clamp(0.0, maxY),
                  );

                  marketProvider.updateLotPosition(
                      i, boundedPosition - lot['position']);
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
            selectedDate: _selectedDate,
          ),
        ),
      );
    });
  }

  void _showEditLotBottomSheet(BuildContext context, int index) async {
    final marketProvider = Provider.of<MarketProvider>(context, listen: false);
    final lot = marketProvider.lots[index];

    final nameController = TextEditingController(text: lot['name']);
    final detailsController = TextEditingController(text: lot['details']);
    final priceController =
        TextEditingController(text: lot['price'].toString());
    final widthController =
        TextEditingController(text: lot['size'].width.toString());
    final heightController =
        TextEditingController(text: lot['size'].height.toString());
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
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            decoration: InputDecoration(
                              labelText: 'Price',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: widthController,
                            decoration: InputDecoration(
                              labelText: 'Width (cm)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.width_normal),
                              helperText: 'Min: 100cm',
                              errorText:
                                  (double.tryParse(widthController.text) ?? 0) <
                                          100
                                      ? 'Minimum 100cm'
                                      : null,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: heightController,
                            decoration: InputDecoration(
                              labelText: 'Height (cm)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.height),
                              helperText: 'Min: 100cm',
                              errorText:
                                  (double.tryParse(heightController.text) ??
                                              0) <
                                          100
                                      ? 'Minimum 100cm'
                                      : null,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Available for rent'),
                        Spacer(),
                        Switch(
                          value: isAvailable,
                          onChanged: (value) =>
                              setState(() => isAvailable = value),
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
                              final width = double.parse(widthController.text);
                              final height =
                                  double.parse(heightController.text);
                              final price = double.parse(priceController.text);

                              if (width < 100 || height < 100) {
                                throw 'Minimum size is 100cm x 100cm';
                              }

                              if (price <= 0) {
                                throw 'Price must be greater than 0';
                              }

                              final success = await marketProvider.updateLot(
                                index: index,
                                name: nameController.text,
                                details: detailsController.text,
                                price: price,
                                available: isAvailable,
                                size: Size(width, height),
                                context: context,
                              );

                              if (success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Lot updated successfully'),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: Colors.white),
                                      SizedBox(width: 8),
                                      Expanded(child: Text(e.toString())),
                                    ],
                                  ),
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
          },
        );
      },
    );

    // Dispose controllers
    nameController.dispose();
    detailsController.dispose();
    priceController.dispose();
    widthController.dispose();
    heightController.dispose();
  }
}

class LotWidget extends StatelessWidget {
  final Map<String, dynamic> lot;
  final bool isLandlord;
  final DateTime selectedDate;

  const LotWidget({
    Key? key,
    required this.lot,
    required this.isLandlord,
    required this.selectedDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final bool isAvailable = lot['available'] ?? false;
    final normalizedDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final bool isDateAvailable =
        bookingProvider.isDateAvailable(lot['id'], normalizedDate);
    final bool isDatePending =
        bookingProvider.isDatePending(lot['id'], normalizedDate);
    final bool isMyPending =
        _isMyPendingBooking(context, lot['id'], normalizedDate);

    final displayStatus = _determineDisplayStatus(
      isAvailable,
      isDateAvailable,
      isDatePending,
      isMyPending,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        width: lot['size'].width,
        height: lot['size'].height,
        decoration: BoxDecoration(
          color: displayStatus.color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: displayStatus.borderColor,
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
                      'THB ${lot['price'].toStringAsFixed(0)}',
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
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Text(
                displayStatus.text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isMyPendingBooking(BuildContext context, String lotId, DateTime date) {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      final currentUserId = authProvider.userId;

      if (currentUserId == null) return false;

      final normalizedDate = DateTime(date.year, date.month, date.day);
      return bookingProvider.isDatePendingForCurrentUser(lotId, normalizedDate);
    } catch (e) {
      print('Error checking pending booking: $e');
      return false;
    }
  }

  DisplayStatus _determineDisplayStatus(
    bool isAvailable,
    bool isDateAvailable,
    bool isDatePending,
    bool isMyPending,
  ) {
    if (!isAvailable) {
      return DisplayStatus(
        color: Colors.grey.withOpacity(0.7),
        borderColor: Colors.grey[800]!,
        text: 'Unavailable',
      );
    }

    if (isMyPending) {
      return DisplayStatus(
        color: Colors.orange.withOpacity(0.7),
        borderColor: Colors.orange[800]!,
        text: 'Your Request Pending',
      );
    }

    if (isDatePending) {
      return DisplayStatus(
        color: Colors.red.withOpacity(0.7),
        borderColor: Colors.red[800]!,
        text: 'Booking Pending',
      );
    }

    if (!isDateAvailable) {
      return DisplayStatus(
        color: Colors.red.withOpacity(0.7),
        borderColor: Colors.red[800]!,
        text: 'Booked',
      );
    }

    return DisplayStatus(
      color: Colors.green.withOpacity(0.7),
      borderColor: Colors.green[800]!,
      text: 'Available',
    );
  }
}

class DisplayStatus {
  final Color color;
  final Color borderColor;
  final String text;

  const DisplayStatus({
    required this.color,
    required this.borderColor,
    required this.text,
  });
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

Future<Size?> showSizeSelectionDialog(BuildContext context) async {
  final widthController = TextEditingController(text: '100');
  final heightController = TextEditingController(text: '100');

  try {
    return await showDialog<Size>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.square_foot, color: Colors.green),
              SizedBox(width: 8),
              Text('Set Lot Size'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widthController,
                      decoration: InputDecoration(
                        labelText: 'Width (cm)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.width_normal),
                        helperText: 'Min: 100cm',
                        errorText:
                            (double.tryParse(widthController.text) ?? 0) < 100
                                ? 'Minimum 100cm'
                                : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: heightController,
                      decoration: InputDecoration(
                        labelText: 'Height (cm)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.height),
                        helperText: 'Min: 100cm',
                        errorText:
                            (double.tryParse(heightController.text) ?? 0) < 100
                                ? 'Minimum 100cm'
                                : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                try {
                  final width = double.parse(widthController.text);
                  final height = double.parse(heightController.text);

                  if (width < 100 || height < 100) {
                    throw 'Minimum size is 100cm x 100cm';
                  }

                  Navigator.pop(context, Size(width, height));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(e is String
                                ? e
                                : 'Please enter valid dimensions'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text('Confirm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  } finally {
    widthController.dispose();
    heightController.dispose();
  }
}
