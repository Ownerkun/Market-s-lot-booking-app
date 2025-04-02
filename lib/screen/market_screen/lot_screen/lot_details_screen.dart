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
  final DateTime selectedDate;

  const LotDetailsScreen({
    Key? key,
    required this.lot,
    required this.marketId,
    required this.onSave,
    required this.isLandlord,
    required this.selectedDate,
  }) : super(key: key);

  @override
  _LotDetailsScreenState createState() => _LotDetailsScreenState();
}

class _LotDetailsScreenState extends State<LotDetailsScreen> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  late BookingProvider _bookingProvider;
  bool _isLoading = false;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _selectedDateRange = null; // Initialize selected range as null

    _bookingProvider = Provider.of<BookingProvider>(context, listen: false);

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

  bool _isDateRangeAvailable(DateTime start, DateTime end) {
    DateTime current = start;
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      if (!_isDateAvailable(current) || _isDatePending(current)) {
        return false;
      }
      current = current.add(Duration(days: 1));
    }
    return true;
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

  Future<void> _bookLot(DateTimeRange dateRange) async {
    setState(() {
      _isLoading = true;
    });

    final success = await _bookingProvider.requestBooking(
      widget.lot['id'],
      dateRange.start,
      dateRange.end,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Booking successful for ${DateFormat('MMMM d').format(dateRange.start)} to ${DateFormat('MMMM d, yyyy').format(dateRange.end)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh booked dates after successful booking
      await _loadBookedDates(_focusedDay);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_bookingProvider.errorMessage ?? 'Failed to book lot'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showBookingConfirmation(DateTimeRange dateRange) async {
    final duration = dateRange.end.difference(dateRange.start).inDays + 1;
    final totalPrice = widget.lot['price'] * duration;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.shopping_cart_checkout, color: Colors.green),
              SizedBox(width: 8),
              Text('Confirm Booking'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Booking Details:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              _buildConfirmationRow(
                Icons.store,
                'Lot',
                widget.lot['name'],
              ),
              SizedBox(height: 8),
              _buildConfirmationRow(
                Icons.calendar_today,
                'Dates',
                '${DateFormat('MMM d').format(dateRange.start)} - ${DateFormat('MMM d').format(dateRange.end)}',
              ),
              SizedBox(height: 8),
              _buildConfirmationRow(
                Icons.timer,
                'Duration',
                '$duration day${duration > 1 ? 's' : ''}',
              ),
              SizedBox(height: 8),
              _buildConfirmationRow(
                Icons.attach_money,
                'Price per day',
                '\$${widget.lot['price'].toStringAsFixed(2)}',
              ),
              Divider(),
              _buildConfirmationRow(
                Icons.summarize,
                'Total Price',
                '\$${totalPrice.toStringAsFixed(2)}',
                isTotal: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _bookLot(dateRange);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Confirm Booking'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmationRow(IconData icon, String label, String value,
      {bool isTotal = false}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.green),
        SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
            color: isTotal ? Colors.green : Colors.black87,
          ),
        ),
      ],
    );
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
                                    rangeStartDay: _selectedDateRange?.start,
                                    rangeEndDay: _selectedDateRange?.end,
                                    calendarFormat: CalendarFormat.month,
                                    rangeSelectionMode:
                                        RangeSelectionMode.toggledOn,
                                    onRangeSelected: (start, end, focusedDay) {
                                      if (start == null || end == null) return;

                                      final isRangeAvailable =
                                          _isDateRangeAvailable(start, end);

                                      if (!isRangeAvailable) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Some dates in this range are not available'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      } else {
                                        setState(() {
                                          _selectedDateRange = DateTimeRange(
                                              start: start, end: end);
                                          _focusedDay = focusedDay;
                                        });
                                      }
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
                                      rangeStartDecoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      rangeEndDecoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      withinRangeTextStyle: TextStyle(
                                        color: Colors.white,
                                      ),
                                      rangeHighlightColor:
                                          Colors.green.withOpacity(0.2),
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
            onPressed: (_selectedDateRange != null &&
                    widget.lot['available'] &&
                    !widget.isLandlord &&
                    !_isLoading)
                ? () => _showBookingConfirmation(_selectedDateRange!)
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
                    _selectedDateRange != null
                        ? 'Book ${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}'
                        : 'Select dates to book',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
