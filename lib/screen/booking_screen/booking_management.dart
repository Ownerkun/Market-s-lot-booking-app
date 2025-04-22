import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/screen/booking_screen/booking_details.dart';
import 'package:market_lot_app/widgets/booking_filter.dart';

class LandlordBookingsPage extends StatefulWidget {
  const LandlordBookingsPage({Key? key}) : super(key: key);

  @override
  _LandlordBookingsPageState createState() => _LandlordBookingsPageState();
}

class _LandlordBookingsPageState extends State<LandlordBookingsPage> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _isInitialized = false;
  bool _isUpdating = false;
  bool _isFilterExpanded = false;
  Map<String, dynamic> _filters = {};
  List<dynamic> _allBookings = [];
  Map<String, List<dynamic>> _pendingBookingsByMarket = {};
  Map<String, List<dynamic>> _historyBookingsByMarket = {};
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

    bookingProvider.fetchLandlordBookings().then((_) {
      if (mounted) {
        setState(() {
          _allBookings = bookingProvider.bookings;
          _markets = _extractMarketNames(_allBookings);
        });
        _applyFilters();
      }
    }).catchError((error) {
      if (mounted) {
        print('Error fetching bookings: $error');
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
    if (!mounted) return;

    try {
      final pending = <String, List<dynamic>>{};
      final history = <String, List<dynamic>>{};

      for (var booking in _allBookings) {
        try {
          final lot = booking['lot'] as Map<String, dynamic>?;
          if (lot == null) {
            print('Warning: Booking has no lot information');
            continue;
          }

          final marketId = lot['marketId']?.toString() ?? 'unknown';
          final market = lot['market'] as Map<String, dynamic>?;
          final marketName = booking['lot']?['market']?['name'] ??
              'Market ${marketId.substring(0, 8)}...';
          final status =
              booking['status']?.toString().toUpperCase() ?? 'UNKNOWN';

          if (_filters.isNotEmpty) {
            if (_filters.containsKey('status') &&
                _filters['status'] != status) {
              continue;
            }
            if (_filters.containsKey('market') &&
                _filters['market'] != marketName) {
              continue;
            }
          }

          final bookingWithDates = {
            ...booking,
            'marketName': marketName,
            'startDate': booking['startDate'],
            'endDate': booking['endDate'],
            'processedAt': DateTime.now().toIso8601String(),
          };

          switch (status) {
            case 'PENDING':
              pending.putIfAbsent(marketId, () => []).add(bookingWithDates);
              break;
            default:
              history.putIfAbsent(marketId, () => []).add(bookingWithDates);
              break;
          }
        } catch (e, stackTrace) {
          print('Error processing booking: $e');
          print('Stack trace: $stackTrace');
          continue;
        }
      }

      for (var marketBookings in [...pending.values, ...history.values]) {
        marketBookings.sort((a, b) {
          final aDate = DateTime.parse(a['startDate']);
          final bDate = DateTime.parse(a['startDate']);
          return bDate.compareTo(aDate);
        });
      }

      setState(() {
        _pendingBookingsByMarket = pending;
        _historyBookingsByMarket = history;
      });
    } catch (e, stackTrace) {
      print('Error grouping bookings: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing bookings'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleFilterExpanded() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
    });
  }

  void _onFilterChanged(Map<String, dynamic> filters) {
    setState(() {
      _filters = filters;
      _isFilterExpanded = false;
    });
    _applyFilters();
  }

  Widget _buildBookingCard(dynamic booking, BuildContext context) {
    final status = booking['status'];
    final lotName = booking['lot']['name'];
    final startDate = DateTime.parse(booking['startDate']);
    final endDate = DateTime.parse(booking['endDate']);
    final tenantName = booking['tenant']?['name'] ?? 'Unknown Tenant';
    final tenantEmail = booking['tenant']?['email'] ?? 'N/A';
    final tenantPhone = booking['tenant']?['phone'] ?? 'N/A';
    final duration = endDate.difference(startDate).inDays + 1;
    final lotWidth = booking['lot']?['shape']?['width']?.toDouble() ?? 0.0;
    final lotHeight = booking['lot']?['shape']?['height']?.toDouble() ?? 0.0;
    final lotSize = '${lotWidth}x${lotHeight} cm';
    final lotPrice = booking['lot']?['price']?.toDouble() ?? 0.0;
    final totalPrice = lotPrice * duration;
    final paymentStatus = booking['paymentStatus'] ?? 'Waiting for payment';
    final paymentMethod = booking['paymentMethod'] ?? 'QR Code / Bank Transfer';
    final paymentDue = booking['paymentDue'] ?? 'within 3 days';

    return Padding(
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
                        text: 'Name: ',
                        style: TextStyle(color: Colors.black87),
                      ),
                      TextSpan(
                        text: tenantName,
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
                padding: EdgeInsets.fromLTRB(12, 4, 12, 16),
                child: Text(
                  '🔹 Lot Name: $lotName\n'
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
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _isUpdating
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Confirm Approval'),
                                        content: Text(
                                            'Are you sure you want to approve this booking?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text('No'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text('Yes'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      final marketId =
                                          booking['lot']?['marketId'];
                                      if (marketId != null) {
                                        _updateBookingStatus(booking['id'],
                                            'APPROVED', marketId);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Approve'),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isUpdating
                                ? null
                                : () async {
                                    final reason = await showDialog<String>(
                                      context: context,
                                      builder: (context) =>
                                          RejectionReasonDialog(),
                                    );
                                    if (reason != null) {
                                      final marketId =
                                          booking['lot']?['marketId'];
                                      if (marketId != null) {
                                        _updateBookingStatus(
                                            booking['id'], 'REJECTED', marketId,
                                            reason: reason);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Reject'),
                          ),
                        ],
                      ),
                    if (status == 'APPROVED')
                      ElevatedButton(
                        onPressed: _isUpdating
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Confirm Cancellation'),
                                    content: Text(
                                        'Are you sure you want to cancel this booking?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text('No'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text('Yes'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  final marketId = booking['lot']?['marketId'];
                                  if (marketId != null) {
                                    _updateBookingStatus(
                                        booking['id'], 'CANCELLED', marketId);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Cancel Booking'),
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

  Future<void> _updateBookingStatus(
      String bookingId, String status, String marketId,
      {String? reason}) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);

      final success = await bookingProvider.updateBookingStatus(
        bookingId,
        status,
        marketId: marketId,
        reason: reason,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking $status successfully!'),
            backgroundColor: _getStatusColor(status),
          ),
        );

        await bookingProvider.fetchLandlordBookings();

        final booking = bookingProvider.bookings.firstWhere(
          (b) => b['id'] == bookingId,
          orElse: () => null,
        );

        if (booking != null && booking['lot'] != null) {
          await bookingProvider.refreshLotAvailability(
            booking['lot']['id'],
            marketId: marketId,
          );
        }

        setState(() {
          _allBookings = bookingProvider.bookings;
          _markets = _extractMarketNames(_allBookings);
        });
        _applyFilters();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bookingProvider.errorMessage ??
                'Failed to update booking status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'CANCELLED':
        return Colors.orange;
      default:
        return Colors.grey;
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

  Widget _buildBookingsList(Map<String, List<dynamic>> bookingsMap) {
    return ListView.builder(
      itemCount: bookingsMap.length,
      itemBuilder: (context, marketIndex) {
        final marketId = bookingsMap.keys.elementAt(marketIndex);
        final marketBookings = bookingsMap[marketId]!;
        final marketName = marketBookings.first['marketName'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                marketName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
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

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final statuses = ['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Booking Management'),
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
              Tab(text: 'Pending Requests'),
              Tab(text: 'Booking History'),
            ],
          ),
        ),
        body: Column(
          children: [
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
            Expanded(
              child: TabBarView(
                children: [
                  bookingProvider.isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _pendingBookingsByMarket.isEmpty
                          ? _buildEmptyState('No pending booking requests')
                          : RefreshIndicator(
                              onRefresh: () async {
                                await bookingProvider.fetchLandlordBookings();
                                setState(() {
                                  _allBookings = bookingProvider.bookings;
                                  _markets = _extractMarketNames(_allBookings);
                                });
                                _applyFilters();
                              },
                              child:
                                  _buildBookingsList(_pendingBookingsByMarket),
                            ),
                  bookingProvider.isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _historyBookingsByMarket.isEmpty
                          ? _buildEmptyState('No booking history yet')
                          : RefreshIndicator(
                              onRefresh: () async {
                                await bookingProvider.fetchLandlordBookings();
                                setState(() {
                                  _allBookings = bookingProvider.bookings;
                                  _markets = _extractMarketNames(_allBookings);
                                });
                                _applyFilters();
                              },
                              child:
                                  _buildBookingsList(_historyBookingsByMarket),
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

class RejectionReasonDialog extends StatefulWidget {
  @override
  _RejectionReasonDialogState createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<RejectionReasonDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rejection Reason'),
      content: TextField(
        controller: _reasonController,
        decoration: InputDecoration(
          hintText: 'Enter reason for rejection',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_reasonController.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text('Submit'),
        ),
      ],
    );
  }
}
