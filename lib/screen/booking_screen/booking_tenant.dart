import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/screen/booking_screen/booking_details.dart';
// Import the BookingFilter widget
import 'package:market_lot_app/widgets/booking_filter.dart';

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchAndGroupBookings();
        }
      });
    }
  }

  void _fetchAndGroupBookings() {
    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);

    bookingProvider.fetchTenantBookings().then((_) {
      if (mounted) {
        setState(() {
          _allBookings = bookingProvider.bookings;
          // Extract unique market names
          _markets = _extractMarketNames(_allBookings);
        });
        _applyFilters();
      }
    }).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bookings: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
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
      final bDate = DateTime.parse(b['startDate']);
      return bDate.compareTo(aDate);
    });

    setState(() {
      _activeBookings = active;
      _historyBookings = history;
    });
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
    final status = booking['status'];
    final lotName = booking['lot']?['name'] ?? 'Unknown Lot';
    final marketId = booking['lot']?['marketId'] ?? '';
    final marketName = booking['lot']?['market']?['name'] ?? 'Unknown Market';
    final startDate = DateTime.parse(booking['startDate']);
    final endDate = DateTime.parse(booking['endDate']);
    final duration = endDate.difference(startDate).inDays + 1;
    final lotWidth = booking['lot']?['shape']?['width']?.toDouble() ?? 0.0;
    final lotHeight = booking['lot']?['shape']?['height']?.toDouble() ?? 0.0;
    final lotSize = '${lotWidth}x${lotHeight} cm';
    final lotPrice = booking['lot']?['price']?.toDouble() ?? 0.0;
    final totalPrice = lotPrice * duration;
    final paymentStatus = booking['paymentStatus'] ?? 'Waiting for payment';
    final paymentMethod = booking['paymentMethod'] ?? 'QR Code / Bank Transfer';
    final paymentDue = booking['paymentDue'] ?? 'Within 7 days';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContractDetailScreen(contract: {
              ...booking,
              'id': booking['id'] ?? 'N/A',
              'status': status,
              'lot': {
                ...booking['lot'],
                'market': {
                  'name': marketName,
                  'id': marketId,
                },
              },
              'tenant': {
                'name': 'Loading...',
                'email': 'N/A',
                'phone': 'N/A',
                'id': booking['tenantId'],
              },
              'startDate': booking['startDate'],
              'endDate': booking['endDate'],
            }),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: 570),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 0, 8),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Lot Name: ',
                          style: TextStyle(color: Colors.black87),
                        ),
                        TextSpan(
                          text: lotName,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ],
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: Text(
                    'Details of Booking',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Text(
                    '🔹 Market: $marketName',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, 16),
                  child: Text(
                    '🔹 Lot Size: $lotSize\n'
                    '🔹 Rental Period: ${DateFormat('d MMM yyyy').format(startDate)} - ${DateFormat('d MMM yyyy').format(endDate)}\n'
                    '🔹 Duration: $duration day${duration > 1 ? 's' : ''}\n'
                    '🔹 Daily Price: ${NumberFormat('#,##0.00').format(lotPrice)} THB\n'
                    '🔹 Total Price: ${NumberFormat('#,##0.00').format(totalPrice)} THB\n'
                    '🔹 Payment Status: $paymentStatus\n'
                    '🔹 Payment Method: $paymentMethod\n'
                    '🔹 Payment Due: $paymentDue',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
                Divider(
                  height: 2,
                  thickness: 1,
                  color: Theme.of(context).dividerColor,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: _getStatusChipColor(status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusChipColor(status),
                            width: 2,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: _getStatusChipColor(status),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (status == 'PENDING')
                        ElevatedButton(
                          onPressed: () => _cancelBooking(booking['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Cancel Request'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 100,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);

    // All possible statuses
    final statuses = ['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('My Bookings'),
          backgroundColor: Colors.green,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(_isFilterExpanded
                  ? Icons.filter_list_off
                  : Icons.filter_list),
              onPressed: _toggleFilterExpanded,
              tooltip: 'Filter Bookings',
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Active Bookings'),
              Tab(text: 'Booking History'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Filter Section
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: _isFilterExpanded ? null : 0,
              child: SingleChildScrollView(
                child: _isFilterExpanded
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: BookingFilter(
                          statuses: statuses,
                          markets: _markets,
                          initialFilters: _filters,
                          onFilterChanged: _onFilterChanged,
                        ),
                      )
                    : SizedBox.shrink(),
              ),
            ),

            // Active Filter Indicators
            if (_filters.isNotEmpty)
              Container(
                color: Colors.grey.shade100,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.filter_alt, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Filters Applied: ${_filters.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filters = {};
                        });
                        _applyFilters();
                      },
                      child: Text('Clear All'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),

            // Booking Lists
            Expanded(
              child: TabBarView(
                children: [
                  // Active Bookings Tab
                  bookingProvider.isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _activeBookings.isEmpty
                          ? _buildEmptyState('No active or pending bookings')
                          : RefreshIndicator(
                              onRefresh: () async {
                                await bookingProvider.fetchTenantBookings();
                                setState(() {
                                  _allBookings = bookingProvider.bookings;
                                  // Extract unique market names
                                  _markets = _extractMarketNames(_allBookings);
                                });
                                _applyFilters();
                              },
                              child: ListView.builder(
                                itemCount: _activeBookings.length,
                                itemBuilder: (context, index) {
                                  return _buildBookingCard(
                                      _activeBookings[index], context);
                                },
                              ),
                            ),

                  // Booking History Tab
                  bookingProvider.isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _historyBookings.isEmpty
                          ? _buildEmptyState('No past bookings')
                          : RefreshIndicator(
                              onRefresh: () async {
                                await bookingProvider.fetchTenantBookings();
                                setState(() {
                                  _allBookings = bookingProvider.bookings;
                                  // Extract unique market names
                                  _markets = _extractMarketNames(_allBookings);
                                });
                                _applyFilters();
                              },
                              child: ListView.builder(
                                itemCount: _historyBookings.length,
                                itemBuilder: (context, index) {
                                  return _buildBookingCard(
                                      _historyBookings[index], context);
                                },
                              ),
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
