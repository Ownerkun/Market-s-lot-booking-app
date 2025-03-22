import 'package:flutter/material.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class LotDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> lot;
  final String marketId;
  final bool isLandlord;
  final Function(String name, String details, double price, bool available)
      onSave;

  const LotDetailsScreen({
    Key? key,
    required this.lot,
    required this.marketId,
    required this.isLandlord,
    required this.onSave,
  }) : super(key: key);

  @override
  _LotDetailsScreenState createState() => _LotDetailsScreenState();
}

class _LotDetailsScreenState extends State<LotDetailsScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  List<DateTime> _bookedDates = [];
  bool _isLoading = true;
  bool _isAvailable = false;
  String? _availabilityError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookedDates();
    });
  }

  Future<void> _loadBookedDates() async {
    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);

    try {
      setState(() {
        _isLoading = true;
      });

      _bookedDates =
          await bookingProvider.fetchLotBookedDates(widget.lot['id'] ?? '');
      await _checkAvailability(_selectedDay);
    } catch (e) {
      setState(() {
        _availabilityError = 'Could not load availability data';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAvailability(DateTime date) async {
    if (!widget.lot['available']) {
      setState(() {
        _isAvailable = false;
      });
      return;
    }

    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);

    try {
      final isAvailable = await bookingProvider.checkLotAvailability(
        widget.lot['id'] ?? '',
        date,
      );

      setState(() {
        _isAvailable = isAvailable;
        _availabilityError = null;
      });
    } catch (e) {
      setState(() {
        _availabilityError = 'Could not check availability';
        _isAvailable = false;
      });
    }
  }

  void _showEditLotDialog() async {
    TextEditingController nameController =
        TextEditingController(text: widget.lot['name']);
    TextEditingController detailsController =
        TextEditingController(text: widget.lot['details']);
    TextEditingController priceController =
        TextEditingController(text: widget.lot['price'].toString());
    bool isAvailable = widget.lot['available'] ?? false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Edit Lot'),
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
                  SwitchListTile(
                    title: Text('Available'),
                    value: isAvailable,
                    onChanged: (value) {
                      setState(() {
                        isAvailable = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.onSave(
                    nameController.text,
                    detailsController.text,
                    double.tryParse(priceController.text) ?? 0.0,
                    isAvailable,
                  );
                  Navigator.pop(context);
                },
                child: Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isDateBooked(DateTime day) {
    return _bookedDates.any((bookedDate) => isSameDay(bookedDate, day));
  }

  Future<void> _bookLot() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);

      final success = await bookingProvider.requestBooking(
        widget.lot['id'],
        _selectedDay,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh booked dates after successful booking
        await _loadBookedDates();
      } else {
        throw Exception(
            bookingProvider.errorMessage ?? 'Failed to request booking');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to request booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lot['name'] ?? 'Lot Details'),
        actions: [
          if (widget.isLandlord)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: _showEditLotDialog,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // App Bar with image background
                SliverAppBar(
                  expandedHeight: MediaQuery.of(context).size.height * 0.35,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.green,
                  actions: [
                    if (widget.isLandlord)
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.white),
                        onPressed: () {
                          _showEditLotDialog();
                        },
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Lot image
                        Image.network(
                          'https://picsum.photos/800/600',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: Center(
                                child: Icon(
                                  Icons.error,
                                  color: Colors.red,
                                  size: 50,
                                ),
                              ),
                            );
                          },
                        ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                        // Lot name and price
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lot['name'],
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '\$${widget.lot['price']}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: widget.lot['available']
                                          ? Colors.green
                                          : Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      widget.lot['available']
                                          ? 'Available'
                                          : 'Not Available',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Lot details content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Details section
                        _buildSectionTitle('About This Lot'),
                        SizedBox(height: 8),
                        _buildInfoCard(
                          child: Text(
                            widget.lot['details'],
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(height: 24),

                        // Features section
                        _buildSectionTitle('Features'),
                        SizedBox(height: 8),
                        _buildInfoCard(
                          child: Column(
                            children: [
                              _buildFeatureRow(Icons.aspect_ratio, 'Size',
                                  '${widget.lot['size'].width.toInt()} x ${widget.lot['size'].height.toInt()} ft'),
                              Divider(),
                              _buildFeatureRow(Icons.location_on, 'Location',
                                  'Section A, West Wing'),
                              Divider(),
                              _buildFeatureRow(
                                  Icons.event_available,
                                  'Availability',
                                  widget.lot['available']
                                      ? 'Available'
                                      : 'Not Available'),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),

                        // Calendar section
                        _buildSectionTitle('Select Booking Date'),
                        SizedBox(height: 8),
                        _buildInfoCard(
                          child: Column(
                            children: [
                              TableCalendar(
                                firstDay: DateTime.utc(2020, 1, 1),
                                lastDay: DateTime.utc(2030, 12, 31),
                                focusedDay: _focusedDay,
                                selectedDayPredicate: (day) =>
                                    isSameDay(_selectedDay, day),
                                onDaySelected: (selectedDay, focusedDay) {
                                  setState(() {
                                    _selectedDay = selectedDay;
                                    _focusedDay = focusedDay;
                                  });
                                  _checkAvailability(selectedDay);
                                },
                                calendarStyle: CalendarStyle(
                                  todayDecoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  selectedDecoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, date, events) {
                                    if (_isDateBooked(date)) {
                                      return Positioned(
                                        right: 1,
                                        bottom: 1,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          width: 8,
                                          height: 8,
                                        ),
                                      );
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    _buildLegendItem(Colors.green, 'Selected'),
                                    SizedBox(width: 16),
                                    _buildLegendItem(Colors.red, 'Booked'),
                                  ],
                                ),
                              ),
                              if (_availabilityError != null)
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    _availabilityError!,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    Text(
                                      'Selected date: ${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    _isDateBooked(_selectedDay)
                                        ? Text(
                                            'This date is already booked',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : _isAvailable
                                            ? Text(
                                                'This date is available for booking',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : Text(
                                                'This date is not available',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed:
                (_isAvailable && !_isDateBooked(_selectedDay) && !_isLoading)
                    ? _bookLot
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              disabledBackgroundColor: Colors.grey[300],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? CircularProgressIndicator(color: Colors.white)
                : Text(
                    'Book for ${DateFormat('MMM d').format(_selectedDay)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFeatureRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
