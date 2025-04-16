import 'package:flutter/material.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/provider/market_provider.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';

class MarketReportScreen extends StatefulWidget {
  @override
  _MarketReportScreenState createState() => _MarketReportScreenState();
}

class _MarketReportScreenState extends State<MarketReportScreen> {
  bool _isLoading = false;
  String? _selectedMarketId;
  List<Map<String, dynamic>> _landlordMarkets = [];
  late BookingProvider _bookingProvider;
  late MarketProvider _marketProvider;

  // Date selection state
  DateTime? _selectedDate;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime _focusedDay = DateTime.now();
  bool _dateFilterActive = false;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;
  DateTimeRange? _selectedDateRange;
  bool _isRangeSelection = true;

  List<Map<String, dynamic>> get displayedBookings {
    final bookings = _selectedMarketId == null
        ? _bookingProvider.bookings
        : _bookingProvider.bookings
            .where((b) => b['lot']?['marketId'] == _selectedMarketId)
            .toList();

    return bookings
        .where((booking) {
          if (!_dateFilterActive) return true;

          try {
            final bookingDate =
                DateTime.parse(booking['createdAt'] ?? booking['startDate']);

            if (_selectedDate != null &&
                _rangeStart == null &&
                _rangeEnd == null) {
              return isSameDay(bookingDate, _selectedDate!);
            }

            return (_rangeStart == null ||
                    bookingDate
                        .isAfter(_rangeStart!.subtract(Duration(days: 1)))) &&
                (_rangeEnd == null ||
                    bookingDate.isBefore(_rangeEnd!.add(Duration(days: 1))));
          } catch (e) {
            print('Error parsing date: $e');
            return true;
          }
        })
        .cast<Map<String, dynamic>>()
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    _marketProvider = Provider.of<MarketProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      final marketProvider =
          Provider.of<MarketProvider>(context, listen: false);

      // Always load markets first
      await authProvider.fetchMarkets();
      _landlordMarkets = authProvider.markets;

      // Load bookings - filtered by selected market if specified
      await bookingProvider.fetchLandlordBookings(marketId: _selectedMarketId);

      // Only fetch lots if a specific market is selected
      if (_selectedMarketId != null) {
        // Create a new MarketProvider instance for the selected market
        final specificMarketProvider =
            MarketProvider(_selectedMarketId!, authProvider);
        await specificMarketProvider.fetchLots(context);
        // Update the main market provider's data
        _marketProvider = specificMarketProvider;
      } else {
        // For "All Markets", we don't need to fetch lots (or fetch all if needed)
        _marketProvider.lots.clear(); // Clear previous market's lots
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMarketDropdown() {
    return DropdownButton<String>(
      value: _selectedMarketId,
      hint: Text('All Markets'),
      onChanged: (String? newValue) async {
        setState(() => _selectedMarketId = newValue);

        // Debug logging
        print('Selected Market ID: $newValue');
        if (newValue != null) {
          final selectedMarket = _landlordMarkets.firstWhere(
            (market) => market['id'] == newValue,
            orElse: () => {'id': 'not found', 'name': 'not found'},
          );
          print('Selected Market Details:');
          print('- Name: ${selectedMarket['name']}');
          print('- ID: ${selectedMarket['id']}');
          print('- Total Lots: ${_marketProvider.lots.length}');
          print('- Total Bookings: ${displayedBookings.length}');

          final metrics = _calculateMetrics();
          print('Market Metrics:');
          print('- Total Lots: ${metrics['totalLots']}');
          print('- Occupied Lots: ${metrics['occupiedLots']}');
          print(
              '- Occupancy Rate: ${metrics['occupancyRate'].toStringAsFixed(1)}%');
          print('- Approved Bookings: ${metrics['approvedBookings']}');
          print(
              '- Total Revenue: \$${metrics['totalRevenue'].toStringAsFixed(2)}');
        } else {
          print('All Markets selected');
          print(
              'Total Bookings across all markets: ${displayedBookings.length}');
        }

        await _loadData(); // Reload data when market changes
      },
      items: [
        DropdownMenuItem(
          value: null,
          child: Text('All Markets'),
        ),
        ..._landlordMarkets.map((market) {
          return DropdownMenuItem(
            value: market['id'],
            child: Text(market['name']),
          );
        }),
      ],
    );
  }

  Map<String, dynamic> _calculateMetrics() {
    final bookings = displayedBookings;
    final lots = _selectedMarketId == null ? [] : _marketProvider.lots;

    final approvedBookings = bookings
        .where((b) => b['status']?.toString().toUpperCase() == 'APPROVED')
        .length;

    final totalLots = lots.length;
    final occupiedLotIds = bookings
        .where((b) => b['status']?.toString().toUpperCase() == 'APPROVED')
        .map((b) => b['lot']?['id'])
        .whereType<String>()
        .toSet();

    final occupiedLots = lots
        .where((lot) =>
            occupiedLotIds.contains(lot['id']) || lot['available'] == false)
        .length;

    final occupancyRate = totalLots > 0 ? (occupiedLots / totalLots * 100) : 0;

    final totalRevenue = bookings.fold(0.0, (sum, booking) {
      if (booking['status']?.toString().toUpperCase() == 'APPROVED') {
        final price = (booking['lot']?['price'] as num?)?.toDouble() ?? 0;
        final days = DateTime.parse(booking['endDate'])
                .difference(DateTime.parse(booking['startDate']))
                .inDays +
            1;
        return sum + (price * days);
      }
      return sum;
    });

    return {
      'totalLots': totalLots,
      'occupiedLots': occupiedLots,
      'occupancyRate': occupancyRate,
      'approvedBookings': approvedBookings,
      'totalRevenue': totalRevenue,
    };
  }

  Widget _buildDateMarker(
      BuildContext context, DateTime date, List<dynamic> events) {
    return SizedBox.shrink(); // No markers needed for report screen
  }

  Widget _buildCalendarLegend() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildLegendItem(Colors.green, 'Selected'),
          SizedBox(width: 16),
          _buildLegendItem(Colors.blue.withOpacity(0.3), 'Today'),
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

  Widget _buildSelectedDateRange() {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        _selectedDate != null
            ? 'Selected date: ${DateFormat('MMMM d, yyyy').format(_selectedDate!)}'
            : _rangeStart != null && _rangeEnd != null
                ? 'Selected range: ${DateFormat('MMMM d, yyyy').format(_rangeStart!)} - ${DateFormat('MMMM d, yyyy').format(_rangeEnd!)}'
                : 'No date selected',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  void _openDatePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select Date Range'),
              content: Container(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          child: Text('Single Day'),
                          onPressed: () {
                            setState(() {
                              _isRangeSelection = false;
                              _selectedDateRange = null;
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: !_isRangeSelection
                                ? Colors.green.withOpacity(0.2)
                                : null,
                          ),
                        ),
                        TextButton(
                          child: Text('Date Range'),
                          onPressed: () {
                            setState(() {
                              _isRangeSelection = true;
                              _selectedDateRange = null;
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: _isRangeSelection
                                ? Colors.green.withOpacity(0.2)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: TableCalendar(
                        firstDay: DateTime.now().subtract(Duration(days: 365)),
                        lastDay: DateTime.now().add(Duration(days: 365)),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) {
                          return _selectedDate != null &&
                              isSameDay(_selectedDate!, day);
                        },
                        rangeStartDay: _rangeStart,
                        rangeEndDay: _rangeEnd,
                        calendarFormat: _calendarFormat,
                        rangeSelectionMode: _rangeSelectionMode,
                        onDaySelected: (selectedDay, focusedDay) {
                          if (_rangeSelectionMode ==
                              RangeSelectionMode.disabled) {
                            setState(() {
                              _selectedDate = selectedDay;
                              _focusedDay = focusedDay;
                              _rangeStart = null;
                              _rangeEnd = null;
                            });
                          }
                        },
                        onRangeSelected: (start, end, focusedDay) {
                          if (_rangeSelectionMode ==
                              RangeSelectionMode.toggledOn) {
                            setState(() {
                              _selectedDate = null;
                              _rangeStart = start;
                              _rangeEnd = end;
                              _focusedDay = focusedDay;
                            });
                          }
                        },
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        },
                        calendarStyle: CalendarStyle(
                          selectedDecoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.3),
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
                          rangeHighlightColor: Colors.green.withOpacity(0.1),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: _buildDateMarker,
                        ),
                      ),
                    ),
                    _buildSelectedDateRange(),
                    _buildCalendarLegend(),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: Text('Clear'),
                  onPressed: () {
                    setState(() {
                      _selectedDate = null;
                      _rangeStart = null;
                      _rangeEnd = null;
                      _dateFilterActive = false;
                    });
                    Navigator.pop(context);
                    _loadData();
                  },
                ),
                TextButton(
                  child: Text('Apply'),
                  onPressed: () {
                    setState(() {
                      _dateFilterActive = _selectedDate != null ||
                          (_rangeStart != null && _rangeEnd != null);
                    });
                    Navigator.pop(context);
                    _loadData();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text('Market Report',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFiltersSection(),
                    SizedBox(height: 12),
                    _buildSummaryCards(),
                    SizedBox(height: 20),
                    _buildBookingTrends(),
                    SizedBox(height: 20),
                    _buildBookingStatusDistribution(),
                    SizedBox(height: 20),
                    _buildTopPerformingLots(),
                    SizedBox(height: 20),
                    _buildRevenueChart(),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFiltersSection() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: _buildMarketDropdown(),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          _buildDateFilter(),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openDatePicker(context),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today, size: 18),
              SizedBox(width: 8),
              Text(
                _selectedDate != null
                    ? DateFormat('MMM d, yyyy').format(_selectedDate!)
                    : _rangeStart != null
                        ? '${DateFormat('MMM d').format(_rangeStart!)}${_rangeEnd != null ? ' - ${DateFormat('MMM d').format(_rangeEnd!)}' : ''}'
                        : 'All Dates',
                style: TextStyle(fontSize: 14),
              ),
              if (_selectedDate != null || _rangeStart != null) ...[
                SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDate = null;
                      _rangeStart = null;
                      _rangeEnd = null;
                      _dateFilterActive = false;
                    });
                    _loadData();
                  },
                  child: Icon(Icons.close, size: 18),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugView() {
    return ExpansionTile(
      title: Text('Debug Data'),
      children: [
        Text('Selected Market: ${_selectedMarketId ?? "All Markets"}'),
        Text('Lots Count: ${_marketProvider.lots.length}'),
        Text('Filtered Bookings Count: ${displayedBookings.length}'),
        if (displayedBookings.isNotEmpty) ...[
          Text('First Booking Lot: ${displayedBookings.first['lot']?['name']}'),
          Text(
              'First Booking Market: ${displayedBookings.first['lot']?['market']?['name']}'),
          Text('First Booking Status: ${displayedBookings.first['status']}'),
        ],
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        return Consumer<MarketProvider>(
          builder: (context, marketProvider, child) {
            final metrics = _calculateMetrics();

            return GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildSummaryCard('Total Lots', metrics['totalLots'].toString(),
                    Icons.grid_view, Colors.blue),
                _buildSummaryCard(
                    'Occupancy Rate',
                    '${metrics['occupancyRate'].toStringAsFixed(1)}%',
                    Icons.person,
                    Colors.green),
                _buildSummaryCard(
                    'Available Lots',
                    (metrics['totalLots'] - metrics['occupiedLots']).toString(),
                    Icons.check_circle,
                    Colors.orange),
                _buildSummaryCard(
                    'Approved Bookings',
                    metrics['approvedBookings'].toString(),
                    Icons.check_circle_outline,
                    Colors.green),
                _buildSummaryCard(
                    'Total Revenue',
                    '\$${metrics['totalRevenue'].toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.purple),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.7), color.withOpacity(0.9)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.85),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingTrends() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Trends',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: LineChart(
                // Implement line chart data here
                LineChartData(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingStatusDistribution() {
    final bookingProvider = Provider.of<BookingProvider>(context);

    final statusCounts = {
      'Approved': bookingProvider.bookings
          .where((b) => b['status'] == 'APPROVED')
          .length,
      'Pending': bookingProvider.bookings
          .where((b) => b['status'] == 'PENDING')
          .length,
      'Rejected': bookingProvider.bookings
          .where((b) => b['status'] == 'REJECTED')
          .length,
      'Cancelled': bookingProvider.bookings
          .where((b) => b['status'] == 'CANCELLED')
          .length,
    };

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Status Distribution',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: statusCounts.entries.map((e) {
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      title: '${e.key}\n${e.value}',
                      color: _getStatusColor(e.key),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Rejected':
        return Colors.red;
      case 'Cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Widget _buildTopPerformingLots() {
    final marketProvider = Provider.of<MarketProvider>(context);
    final lots = marketProvider.lots;

    // Sort lots by revenue or occupancy
    final sortedLots = [...lots]
      ..sort((a, b) => (b['revenue'] ?? 0).compareTo(a['revenue'] ?? 0));

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Lots',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: sortedLots.take(5).length,
              itemBuilder: (context, index) {
                final lot = sortedLots[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(lot['name']),
                  subtitle: Text('Revenue: \$${lot['revenue'] ?? 0}'),
                  trailing: Icon(Icons.trending_up, color: Colors.green),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: BarChart(
                // Implement bar chart data here
                BarChartData(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
