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
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDate;
    _focusedDay = widget.selectedDate;
    _selectedDateRange = null;
    _rangeStart = null;
    _rangeEnd = null;

    _bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookedDates(_focusedDay);
    });
  }

  Future<void> _loadBookedDates(DateTime month) async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);
      await _bookingProvider.loadBookedDatesForLot(widget.lot['id'], month);
      // Don't update _focusedDay here - it's being set by _onPageChanged or the calendar itself
    } catch (e) {
      print('Error loading booked dates: $e');
      _showErrorMessage('Failed to load availability');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleRangeSelection(
      DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _focusedDay = focusedDay;

      if (start != null) {
        // Handle both single-day and range selections
        if (end == null || start == end) {
          // Single day selection
          if (_isDateAvailable(start)) {
            _selectedDateRange = DateTimeRange(start: start, end: start);
            _selectedDay = start;
          } else {
            _showErrorMessage('This date is not available');
            _selectedDateRange = null;
            _rangeStart = null;
            _rangeEnd = null;
          }
        } else {
          // Range selection
          if (_isDateRangeAvailable(start, end)) {
            _selectedDateRange = DateTimeRange(start: start, end: end);
            _selectedDay = start;
          } else {
            _showErrorMessage('Some dates in this range are not available');
            _selectedDateRange = null;
            _rangeStart = null;
            _rangeEnd = null;
          }
        }
      } else {
        _selectedDateRange = null;
      }
    });
  }

  Future<void> _bookLot(DateTimeRange dateRange) async {
    try {
      setState(() => _isLoading = true);

      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      final success = await bookingProvider.requestBooking(
        widget.lot['id'],
        dateRange.start,
        dateRange.end,
      );

      if (success) {
        // Refresh lot availability and booked dates
        await Future.wait([
          bookingProvider.refreshLotAvailability(widget.lot['id']),
          _loadBookedDates(_focusedDay),
        ]);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Booking confirmed for ${DateFormat('MMM d').format(dateRange.start)} - ${DateFormat('MMM d').format(dateRange.end)}',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Reset selection
        setState(() {
          _selectedDateRange = null;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        bookingProvider.errorMessage ?? 'Failed to book lot'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('Error booking lot: $e'); // For debugging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('An error occurred: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showBookingConfirmation(DateTimeRange dateRange) async {
    final bool isOneDay = dateRange.start.year == dateRange.end.year &&
        dateRange.start.month == dateRange.end.month &&
        dateRange.start.day == dateRange.end.day;

    final duration = isOneDay ? 1 : dateRange.duration.inDays + 1;
    final totalPrice = widget.lot['price'] * duration;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.shopping_cart_checkout,
                              color: Colors.white,
                              size: 40,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Confirm Booking',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 24),
                      _buildBookingSummaryCard(
                        dateRange: dateRange,
                        duration: duration,
                        totalPrice: totalPrice,
                      ),
                      SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                side: BorderSide(color: Colors.grey[300]!),
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text('Cancel'),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _bookLot(dateRange);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                'Confirm Booking',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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
        );
      },
    );
  }

  Widget _buildBookingSummaryCard({
    required DateTimeRange dateRange,
    required int duration,
    required num totalPrice,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            Icons.store,
            'Lot',
            widget.lot['name'],
          ),
          Divider(height: 24),
          _buildSummaryRow(
            Icons.calendar_today,
            'Dates',
            '${DateFormat('MMM d').format(dateRange.start)} - ${DateFormat('MMM d').format(dateRange.end)}',
          ),
          Divider(height: 24),
          _buildSummaryRow(
            Icons.timer,
            'Duration',
            '$duration day${duration > 1 ? 's' : ''}',
          ),
          Divider(height: 24),
          _buildSummaryRow(
            Icons.attach_money,
            'Price per day',
            'THB ${widget.lot['price'].toStringAsFixed(2)}',
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildSummaryRow(
              Icons.summarize,
              'Total Price',
              'THB ${totalPrice.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value,
      {bool isTotal = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isTotal ? Theme.of(context).primaryColor : Colors.grey[600],
        ),
        SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? Theme.of(context).primaryColor : Colors.black87,
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

  // Add these helper methods for date availability checking
  bool _isDateAvailable(DateTime day) {
    if (!widget.lot['available']) return false;

    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _bookingProvider.isDateAvailable(widget.lot['id'], normalizedDate) &&
        normalizedDate.isAfter(DateTime.now().subtract(Duration(days: 1)));
  }

  bool _isDatePending(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _bookingProvider.isDatePending(widget.lot['id'], normalizedDate);
  }

  bool _isDateRangeAvailable(DateTime start, DateTime end) {
    if (!widget.lot['available']) return false;

    DateTime current = start;
    while (!current.isAfter(end)) {
      if (!_isDateAvailable(current) || _isDatePending(current)) {
        return false;
      }
      current = current.add(Duration(days: 1));
    }
    return true;
  }

  Widget _buildDateMarker(
      BuildContext context, DateTime date, List<dynamic> events) {
    if (!_isDateAvailable(date)) {
      return _buildMarker(Colors.red);
    }
    if (_isDatePending(date)) {
      return _buildMarker(Colors.orange);
    }
    return SizedBox.shrink();
  }

  Widget _buildMarker(Color color) {
    return Positioned(
      right: 1,
      bottom: 1,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Theme.of(context).primaryColor,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(Duration(days: 365)),
              focusedDay: _focusedDay,
              rangeStartDay: _rangeStart,
              rangeEndDay: _rangeEnd,
              calendarFormat: CalendarFormat.month,
              rangeSelectionMode: RangeSelectionMode.enforced,
              onPageChanged: _onPageChanged,
              onRangeSelected: _handleRangeSelection,
              enabledDayPredicate: _isDateAvailable,
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: Theme.of(context).primaryColor,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                rangeStartDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                rangeEndDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                withinRangeTextStyle: TextStyle(
                  color: Colors.black87,
                ),
                rangeHighlightColor:
                    Theme.of(context).primaryColor.withOpacity(0.1),
                selectedTextStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                outsideTextStyle: TextStyle(color: Colors.grey.shade400),
                weekendTextStyle: TextStyle(color: Colors.black87),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: _buildDateMarker,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarLegend() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(Theme.of(context).primaryColor, 'Selected'),
          _buildLegendItem(Colors.red, 'Booked'),
          _buildLegendItem(Colors.orange, 'Pending'),
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
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingButton() {
    final bool canBook = _selectedDateRange != null &&
        widget.lot['available'] &&
        !widget.isLandlord &&
        !_isLoading;

    final num totalPrice = _selectedDateRange != null
        ? (_selectedDateRange!.start.year == _selectedDateRange!.end.year &&
                _selectedDateRange!.start.month ==
                    _selectedDateRange!.end.month &&
                _selectedDateRange!.start.day == _selectedDateRange!.end.day
            ? widget.lot['price']
            : (_selectedDateRange!.duration.inDays + 1) * widget.lot['price'])
        : 0.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedDateRange != null)
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Price',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'THB ${totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: Theme.of(context).primaryColor,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _selectedDateRange!.start ==
                                      _selectedDateRange!.end
                                  ? '1 day'
                                  : '${_selectedDateRange!.duration.inDays + 1} days',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_selectedDateRange != null) ...[
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.date_range,
                              color: Theme.of(context).primaryColor, size: 16),
                          SizedBox(width: 8),
                          Text(
                            _selectedDateRange!.start == _selectedDateRange!.end
                                ? DateFormat('MMMM d, yyyy')
                                    .format(_selectedDateRange!.start)
                                : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          SafeArea(
            child: ElevatedButton(
              onPressed: canBook
                  ? () => _showBookingConfirmation(_selectedDateRange!)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                disabledBackgroundColor: Colors.grey[300],
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: canBook ? 2 : 0,
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Processing...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          canBook
                              ? Icons.shopping_cart_checkout
                              : Icons.date_range,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          canBook ? 'Confirm Booking' : 'Select dates to book',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTag() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_money, color: Colors.white, size: 18),
          SizedBox(width: 4),
          Text(
            'THB ${widget.lot['price']}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityTag() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: widget.lot['available'] ? Colors.green : Colors.red.shade400,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.lot['available']
                ? Icons.check_circle
                : Icons.cancel_outlined,
            color: Colors.white,
            size: 18,
          ),
          SizedBox(width: 4),
          Text(
            widget.lot['available'] ? 'Available' : 'Not Available',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: MediaQuery.of(context).size.height * 0.3,
                  floating: false,
                  pinned: true,
                  backgroundColor: Theme.of(context).primaryColor,
                  elevation: 0,
                  actions: [
                    if (widget.isLandlord)
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.white),
                        onPressed: () =>
                            _showEditLotDialog(context, widget.lot),
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'lot_${widget.lot['id']}',
                          child: FadeInImage.assetNetwork(
                            placeholder: 'assets/images/placeholder.png',
                            image: 'https://picsum.photos/800/600',
                            fit: BoxFit.cover,
                            imageErrorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: Icon(Icons.image_not_supported,
                                    color: Colors.grey[400], size: 60),
                              );
                            },
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.5),
                                Colors.black.withOpacity(0.8),
                              ],
                              stops: [0.6, 0.8, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lot['name'],
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  _buildPriceTag(),
                                  SizedBox(width: 12),
                                  _buildAvailabilityTag(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                              _buildCalendar(),
                              _buildCalendarLegend(),
                              _buildSelectedDateRange(),
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
      bottomNavigationBar: _buildBookingButton(),
    );
  }

  Widget _buildSelectedDateRange() {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        'Selected date: ${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
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
    return Padding(
      padding: const EdgeInsets.only(left: 2.0, bottom: 12.0, top: 8.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFeatureRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          ),
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
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
