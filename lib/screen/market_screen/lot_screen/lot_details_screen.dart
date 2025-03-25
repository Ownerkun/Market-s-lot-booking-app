import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/provider/booking_provider.dart';

class LotDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> lot;
  final String marketId;
  final Function(String, String, double, bool) onSave;
  final bool isLandlord;

  const LotDetailsScreen({
    Key? key,
    required this.lot,
    required this.marketId,
    required this.onSave,
    required this.isLandlord,
  }) : super(key: key);

  @override
  _LotDetailsScreenState createState() => _LotDetailsScreenState();
}

class _LotDetailsScreenState extends State<LotDetailsScreen> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  late BookingProvider _bookingProvider;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();

    // Initialize _bookingProvider directly in initState
    _bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    // Use addPostFrameCallback to delay the call to loadBookedDates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookedDates(_focusedDay);
    });
  }

  Future<void> _loadBookedDates(DateTime month) async {
    setState(() {
      _isLoading = true;
    });

    await _bookingProvider.loadBookedDatesForLot(widget.lot['id'], month);

    setState(() {
      _isLoading = false;
    });
  }

  bool _isDateAvailable(DateTime day) {
    return _bookingProvider.isDateAvailable(widget.lot['id'], day);
  }

  bool _isDatePending(DateTime day) {
    return _bookingProvider.isDatePending(widget.lot['id'], day);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      if (!_isDateAvailable(selectedDay)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This date is already booked'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (_isDatePending(selectedDay)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This date has a pending booking'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      }
    }
  }

  Future<void> _bookLot() async {
    setState(() {
      _isLoading = true;
    });

    final success =
        await _bookingProvider.requestBooking(widget.lot['id'], _selectedDay);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Booking successful for ${DateFormat('MMMM d, yyyy').format(_selectedDay)}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_bookingProvider.errorMessage ?? 'Failed to book lot'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onPageChanged(DateTime focusedDay) {
    // When calendar page changes, load booked dates for the new month
    _focusedDay = focusedDay;
    _loadBookedDates(focusedDay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          _showEditLotDialog(context, widget.lot);
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
                              _buildFeatureRow(
                                  Icons.aspect_ratio, 'Size', '10 x 10 ft'),
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
                              Consumer<BookingProvider>(
                                builder: (context, bookingProvider, child) {
                                  return TableCalendar(
                                    firstDay: DateTime.now(),
                                    lastDay:
                                        DateTime.now().add(Duration(days: 365)),
                                    focusedDay: _focusedDay,
                                    selectedDayPredicate: (day) =>
                                        isSameDay(_selectedDay, day),
                                    onDaySelected: _onDaySelected,
                                    onPageChanged: _onPageChanged,
                                    calendarStyle: CalendarStyle(
                                      todayDecoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      selectedDecoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      disabledTextStyle: TextStyle(
                                        color: Colors.grey,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    enabledDayPredicate: (day) {
                                      return _isDateAvailable(day) &&
                                          !_isDatePending(day) &&
                                          day.isAfter(DateTime.now()
                                              .subtract(Duration(days: 1)));
                                    },
                                    calendarBuilders: CalendarBuilders(
                                      markerBuilder: (context, date, events) {
                                        if (!_isDateAvailable(date)) {
                                          return Positioned(
                                            right: 1,
                                            bottom: 1,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.red,
                                              ),
                                            ),
                                          );
                                        } else if (_isDatePending(date)) {
                                          return Positioned(
                                            right: 1,
                                            bottom: 1,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                  );
                                },
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    _buildLegendItem(Colors.green, 'Selected'),
                                    SizedBox(width: 16),
                                    _buildLegendItem(Colors.red, 'Booked'),
                                    SizedBox(width: 16),
                                    _buildLegendItem(Colors.orange, 'Pending'),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'Selected date: ${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
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
            onPressed: (widget.lot['available'] &&
                    !widget.isLandlord &&
                    !_isLoading &&
                    _isDateAvailable(_selectedDay) &&
                    !_isDatePending(_selectedDay))
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

  void _showEditLotDialog(
      BuildContext context, Map<String, dynamic> lot) async {
    TextEditingController nameController =
        TextEditingController(text: lot['name']);
    TextEditingController detailsController =
        TextEditingController(text: lot['details']);
    TextEditingController priceController =
        TextEditingController(text: lot['price'].toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Edit Lot',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.store, color: Colors.green),
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
                    prefixIcon: Icon(Icons.description, color: Colors.green),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.attach_money, color: Colors.green),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Save changes
                widget.onSave(nameController.text, detailsController.text,
                    double.parse(priceController.text), lot['available']);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Save'),
            ),
          ],
        );
      },
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
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
