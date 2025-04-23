import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/screen/booking_screen/booking_details.dart';
import 'package:market_lot_app/widgets/booking_filter.dart';
import 'package:market_lot_app/utils/map_helpers.dart';
import 'package:focus_detector/focus_detector.dart';

class TenantBookingsPage extends StatefulWidget {
  const TenantBookingsPage({Key? key}) : super(key: key);

  @override
  _TenantBookingsPageState createState() => _TenantBookingsPageState();
}

class _TenantBookingsPageState extends State<TenantBookingsPage> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _isInitialized = false;
  bool _isFilterExpanded = false;
  bool _isLoading = false;
  List<dynamic> _allBookings = [];
  List<dynamic> _activeBookings = [];
  List<dynamic> _historyBookings = [];
  Map<String, dynamic> _filters = {};
  List<String> _markets = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _fetchAndGroupBookings();
    }
  }

  Future<void> _fetchAndGroupBookings() async {
    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);

    try {
      setState(() {
        _isLoading = true;
      });

      await bookingProvider.fetchTenantBookings();

      if (mounted) {
        setState(() {
          _allBookings = bookingProvider.bookings;
          _markets = _extractMarketNames(_allBookings);
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bookings: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<String> _extractMarketNames(List<dynamic> bookings) {
    final Set<String> marketNames = {};

    for (var booking in bookings) {
      try {
        final marketName = booking['lot']?['market']?['name'];
        if (marketName != null && marketName is String) {
          marketNames.add(marketName);
        }
      } catch (e) {
        print('Error extracting market name: $e');
      }
    }

    return marketNames.toList()..sort();
  }

  void _applyFilters() {
    if (!mounted || _allBookings.isEmpty) return;

    final now = DateTime.now();
    var filteredBookings = List<dynamic>.from(_allBookings);

    // Apply status filter
    if (_filters.containsKey('status') && _filters['status'] != null) {
      filteredBookings = filteredBookings.where((booking) {
        final status = booking['status']?.toString().toUpperCase() ?? 'UNKNOWN';
        return status == _filters['status'];
      }).toList();
    }

    // Apply market filter
    if (_filters.containsKey('market') && _filters['market'] != null) {
      filteredBookings = filteredBookings.where((booking) {
        final marketName = booking['lot']?['market']?['name'] ?? '';
        return marketName == _filters['market'];
      }).toList();
    }

    // Apply date range filter
    if (_filters.containsKey('startDate') && _filters['startDate'] != null) {
      final filterStartDate = DateTime(
        _filters['startDate'].year,
        _filters['startDate'].month,
        _filters['startDate'].day,
      );

      filteredBookings = filteredBookings.where((booking) {
        try {
          final bookingEndDate = DateTime.parse(booking['endDate']);
          return !bookingEndDate.isBefore(filterStartDate);
        } catch (e) {
          return false;
        }
      }).toList();
    }

    if (_filters.containsKey('endDate') && _filters['endDate'] != null) {
      final filterEndDate = DateTime(
        _filters['endDate'].year,
        _filters['endDate'].month,
        _filters['endDate'].day,
      );

      filteredBookings = filteredBookings.where((booking) {
        try {
          final bookingStartDate = DateTime.parse(booking['startDate']);
          return !bookingStartDate.isAfter(filterEndDate);
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Group filtered bookings
    final active = <dynamic>[];
    final history = <dynamic>[];

    for (var booking in filteredBookings) {
      try {
        final endDate = DateTime.parse(booking['endDate']);
        final status = booking['status']?.toString().toUpperCase() ?? 'UNKNOWN';

        // Include both APPROVED and PENDING in active bookings
        if (status == 'APPROVED' && endDate.isAfter(now) ||
            status == 'PENDING') {
          active.add(booking);
        } else {
          history.add(booking);
        }
      } catch (e) {
        print('Error processing booking: $e');
        continue;
      }
    }

    // Sort bookings by date (newest first)
    active.sort((a, b) {
      final aDate = DateTime.parse(a['startDate']);
      final bDate = DateTime.parse(b['startDate']);
      return bDate.compareTo(aDate);
    });

    history.sort((a, b) {
      final aDate = DateTime.parse(a['startDate']);
      final bDate = DateTime.parse(a['startDate']);
      return bDate.compareTo(aDate);
    });

    setState(() {
      _activeBookings = active;
      _historyBookings = history;
    });
  }

  Map<String, List<dynamic>> _groupBookingsByMarket(List<dynamic> bookings) {
    final Map<String, List<dynamic>> grouped = {};

    for (var booking in bookings) {
      final marketId = booking['lot']?['market']?['id'] ?? 'unknown';
      if (!grouped.containsKey(marketId)) {
        grouped[marketId] = [];
      }
      grouped[marketId]!.add({
        ...booking,
        'marketName': booking['lot']?['market']?['name'] ?? 'Unknown Market',
      });
    }

    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) =>
            a.value.first['marketName'].compareTo(b.value.first['marketName'])),
    );
  }

  Widget _buildBookingsList(Map<String, List<dynamic>> bookingsMap) {
    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: 16),
      itemCount: bookingsMap.length,
      itemBuilder: (context, marketIndex) {
        final marketId = bookingsMap.keys.elementAt(marketIndex);
        final marketBookings = bookingsMap[marketId]!;
        final marketName = marketBookings.first['marketName'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade700, Colors.green.shade500],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    offset: Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.store, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      marketName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    '${marketBookings.length} booking${marketBookings.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: marketBookings.length,
              itemBuilder: (context, bookingIndex) {
                return _buildBookingCard(marketBookings[bookingIndex], context);
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleFilterExpanded() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
    });
  }

  void _onFilterChanged(Map<String, dynamic> filters) {
    setState(() {
      _filters = filters;
      // Optionally collapse filter after applying
      _isFilterExpanded = false;
    });
    _applyFilters();
  }

  Widget _buildBookingCard(dynamic booking, BuildContext context) {
    final safeBooking = safeMapCast(booking);
    final safeLot = safeMapCast(safeBooking['lot']);
    final safeMarket = safeMapCast(safeLot['market']);
    final safeShape = safeMapCast(safeLot['shape']);

    final status = safeBooking['status'] ?? 'UNKNOWN';
    final lotName = safeLot['name'] ?? 'Unknown Lot';
    final marketName = safeMarket['name'] ?? 'Unknown Market';
    final startDate = DateTime.parse(
        safeBooking['startDate'] ?? DateTime.now().toIso8601String());
    final endDate = DateTime.parse(
        safeBooking['endDate'] ?? DateTime.now().toIso8601String());
    final duration = endDate.difference(startDate).inDays + 1;
    final lotWidth = (safeShape['width'] ?? 0.0).toDouble();
    final lotHeight = (safeShape['height'] ?? 0.0).toDouble();
    final lotSize = '${lotWidth}x${lotHeight} cm';
    final lotPrice = (safeLot['price'] ?? 0.0).toDouble();
    final totalPrice = lotPrice * duration;
    final paymentStatus = safeBooking['paymentStatus'] ?? 'PENDING';
    final paymentMethod =
        safeBooking['paymentMethod'] ?? 'QR Code / Bank Transfer';
    final paymentDue = safeBooking['paymentDue'] ?? 'Within 7 days';
    final paymentStatusColor = _getPaymentStatusColor(paymentStatus);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            width: 1.0,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ContractDetailScreen(
                  contract: {
                    ...safeBooking,
                    'id': safeBooking['id'] ?? 'N/A',
                    'status': status,
                    'lot': {
                      ...safeLot,
                      'market': {
                        ...safeMarket,
                        'name': marketName,
                      },
                    },
                  },
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Bar
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _getStatusChipColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getStatusChipColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          status,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _getStatusChipColor(status),
                          ),
                        ),
                      ],
                    ),
                    if (paymentStatus != 'VERIFIED')
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: paymentStatusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: paymentStatusColor),
                        ),
                        child: Text(
                          paymentStatus,
                          style: TextStyle(
                            color: paymentStatusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Market Info
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marketName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              Divider(),

              // Booking Details
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 8),

                    // Lot details
                    Row(
                      children: [
                        Expanded(
                          child: _detailItem(
                            context: context,
                            icon: Icons.grid_view,
                            title: 'Lot Name',
                            value: lotName,
                          ),
                        ),
                        Expanded(
                          child: _detailItem(
                            context: context,
                            icon: Icons.straighten,
                            title: 'Size',
                            value: lotSize,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    // Date details
                    Row(
                      children: [
                        Expanded(
                          child: _detailItem(
                            context: context,
                            icon: Icons.calendar_today,
                            title: 'Start Date',
                            value: DateFormat('d MMM yyyy').format(startDate),
                          ),
                        ),
                        Expanded(
                          child: _detailItem(
                            context: context,
                            icon: Icons.calendar_month,
                            title: 'End Date',
                            value: DateFormat('d MMM yyyy').format(endDate),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    // Price details
                    Row(
                      children: [
                        Expanded(
                          child: _detailItem(
                            context: context,
                            icon: Icons.timer,
                            title: 'Duration',
                            value: '$duration day${duration > 1 ? 's' : ''}',
                          ),
                        ),
                        Expanded(
                          child: _detailItem(
                            context: context,
                            icon: Icons.payments_outlined,
                            title: 'Daily Price',
                            value:
                                '${NumberFormat('#,##0.00').format(lotPrice)} THB',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    // Total and payment
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Price:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${NumberFormat('#,##0.00').format(totalPrice)} THB',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.payment, size: 16, color: Colors.grey),
                              SizedBox(width: 4),
                              Text(
                                'Method: $paymentMethod',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 16, color: Colors.grey),
                              SizedBox(width: 4),
                              Text(
                                'Due: $paymentDue',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action button
              if (status == 'PENDING')
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _cancelBooking(safeBooking['id']),
                        icon: Icon(Icons.cancel_outlined),
                        label: Text('Cancel Request'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 18, color: Theme.of(context).primaryColor.withOpacity(0.7)),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusChipColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'PAID':
        return Colors.blue;
      case 'VERIFIED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'EXPIRED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    final booking = _activeBookings.firstWhere(
      (b) => b['id'] == bookingId,
      orElse: () => null,
    );

    if (booking == null || booking['status'] != 'PENDING') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot cancel this booking'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Cancellation'),
        content: Text('Are you sure you want to cancel this booking request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);
    try {
      final success = await bookingProvider.updateBookingStatus(
        bookingId,
        'CANCELLED',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking cancelled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchAndGroupBookings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                bookingProvider.errorMessage ?? 'Failed to cancel booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final statuses = ['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'];

    return FocusDetector(
      onFocusGained: () {
        _fetchAndGroupBookings();
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'My Bookings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green.shade700,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(
                  _isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                  color: Colors.white,
                ),
                onPressed: _toggleFilterExpanded,
                tooltip: 'Filter Bookings',
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  _fetchAndGroupBookings();
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Container(
                color: Colors.green.shade700,
                child: TabBar(
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pending_actions),
                          SizedBox(width: 8),
                          Text('Active'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history),
                          SizedBox(width: 8),
                          Text('History'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      height: _isFilterExpanded ? null : 0,
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: _isFilterExpanded
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          child: _isFilterExpanded
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Filter Bookings',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    BookingFilter(
                                      statuses: statuses,
                                      markets: _markets,
                                      initialFilters: _filters,
                                      onFilterChanged: _onFilterChanged,
                                    ),
                                  ],
                                )
                              : SizedBox.shrink(),
                        ),
                      ),
                    ),
                    if (_filters.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.green.shade100,
                              width: 1,
                            ),
                          ),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.filter_alt,
                                size: 16,
                                color: Colors.green.shade800,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${_filters.entries.length} ${_filters.entries.length == 1 ? 'filter' : 'filters'} applied',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _filters = {};
                                  _isFilterExpanded = false;
                                });
                                _applyFilters();
                              },
                              icon: Icon(Icons.close, size: 16),
                              label: Text('Clear All'),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red.shade700,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.red.shade200),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _activeBookings.isEmpty
                              ? _buildEmptyState(
                                  'No active or pending bookings')
                              : RefreshIndicator(
                                  onRefresh: () => _fetchAndGroupBookings(),
                                  child: _buildBookingsList(
                                      _groupBookingsByMarket(_activeBookings)),
                                ),
                          _historyBookings.isEmpty
                              ? _buildEmptyState('No booking history yet')
                              : RefreshIndicator(
                                  onRefresh: () => _fetchAndGroupBookings(),
                                  child: _buildBookingsList(
                                      _groupBookingsByMarket(_historyBookings)),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                size: 80,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 32),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Pull down to refresh or tap the button below',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchAndGroupBookings,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Refresh Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
