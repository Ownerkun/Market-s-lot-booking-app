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
    final Map<String, dynamic> typedBooking = {
      'id': booking['id']?.toString() ?? 'N/A',
      'status': booking['status']?.toString() ?? 'UNKNOWN',
      'lot': {
        'id': booking['lot']?['id']?.toString() ?? '',
        'name': booking['lot']?['name']?.toString() ?? 'Unknown Lot',
        'marketId': booking['lot']?['marketId']?.toString() ?? '',
        'market': {
          'id': booking['lot']?['market']?['id']?.toString() ?? '',
          'name': booking['lot']?['market']?['name']?.toString() ??
              'Unknown Market',
        },
        'shape': {
          'width': booking['lot']?['shape']?['width']?.toDouble() ?? 0.0,
          'height': booking['lot']?['shape']?['height']?.toDouble() ?? 0.0,
        },
        'price': booking['lot']?['price']?.toDouble() ?? 0.0,
      },
      'tenant': {
        'id': booking['tenant']?['id']?.toString() ?? '',
        'name': booking['tenant']?['name']?.toString() ?? 'Unknown Tenant',
        'email': booking['tenant']?['email']?.toString() ?? 'N/A',
        'phone': booking['tenant']?['phone']?.toString() ?? 'N/A',
      },
      'startDate': booking['startDate']?.toString() ?? '',
      'endDate': booking['endDate']?.toString() ?? '',
      'paymentStatus': booking['paymentStatus']?.toString() ?? 'PENDING',
      'paymentMethod': booking['paymentMethod']?.toString() ?? 'N/A',
      'paymentProofUrl': booking['paymentProofUrl']?.toString(),
      'createdAt': booking['createdAt']?.toString() ?? '',
    };

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
    final paymentStatus = booking['paymentStatus'] ?? 'PENDING';
    final paymentMethod = booking['paymentMethod'] ?? 'QR Code / Bank Transfer';
    final paymentDue = booking['paymentDue'] ?? 'within 3 days';
    final paymentStatusColor = _getPaymentStatusColor(paymentStatus);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ContractDetailScreen(
                  contract: Map<String, dynamic>.from(booking),
                  isLandlordView: true,
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
                        if (booking['paymentProofUrl'] != null) ...[
                          SizedBox(width: 8),
                          Chip(
                            avatar: Icon(Icons.receipt, size: 16),
                            label: Text('Proof Available'),
                            backgroundColor: Colors.blue.shade50,
                          ),
                        ],
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

              // Tenant Info
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenantName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.email_outlined,
                            size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          tenantEmail,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          tenantPhone,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
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

              // Action buttons
              if (status == 'PENDING' || status == 'APPROVED')
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
                      if (status == 'PENDING') ...[
                        OutlinedButton.icon(
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
                                        booking['id'],
                                        'REJECTED',
                                        marketId,
                                        reason: reason,
                                      );
                                    }
                                  }
                                },
                          icon: Icon(Icons.close),
                          label: Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton.icon(
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
                                          child: Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text('Approve'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    final marketId =
                                        booking['lot']?['marketId'];
                                    if (marketId != null) {
                                      _updateBookingStatus(
                                        booking['id'],
                                        'APPROVED',
                                        marketId,
                                      );
                                    }
                                  }
                                },
                          icon: Icon(Icons.check),
                          label: Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                      if (status == 'APPROVED')
                        ElevatedButton.icon(
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
                                          child: Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text('Yes, Cancel Booking'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    final marketId =
                                        booking['lot']?['marketId'];
                                    if (marketId != null) {
                                      _updateBookingStatus(
                                        booking['id'],
                                        'CANCELLED',
                                        marketId,
                                      );
                                    }
                                  }
                                },
                          icon: Icon(Icons.cancel_outlined),
                          label: Text('Cancel Booking'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.orange,
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

  Future<void> _verifyPayment(BuildContext context, String bookingId) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PaymentVerificationDialog(),
    );

    if (result != null) {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      final success = await bookingProvider.verifyPayment(
        bookingId,
        result['isVerified'],
        reason: result['reason'],
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment verification submitted'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchAndGroupBookings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(bookingProvider.errorMessage ?? 'Verification failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy,
              size: 80,
              color: Colors.grey.shade400,
            ),
          ),
          SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchAndGroupBookings,
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final statuses = ['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Booking Management',
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
                        Text('Pending'),
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
        body: Column(
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: _isFilterExpanded ? null : 0,
              curve: Curves.easeInOut,
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: _isFilterExpanded
                      ? BookingFilter(
                          statuses: statuses,
                          markets: _markets,
                          initialFilters: _filters,
                          onFilterChanged: _onFilterChanged,
                        )
                      : SizedBox.shrink(),
                ),
              ),
            ),
            if (_filters.isNotEmpty)
              Container(
                color: Colors.green.shade50,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.filter_alt,
                        size: 16, color: Colors.green.shade800),
                    SizedBox(width: 8),
                    Text(
                      'Active Filters: ${_filters.entries.map((e) => "${e.key}: ${e.value}").join(", ")}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade800,
                      ),
                    ),
                    Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _filters = {};
                        });
                        _applyFilters();
                      },
                      icon: Icon(Icons.close, size: 16),
                      label: Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.report_problem, color: Colors.red),
          SizedBox(width: 8),
          Text('Reject Booking'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for rejecting this booking request:',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide a reason';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_reasonController.text);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text('Submit'),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class PaymentVerificationDialog extends StatefulWidget {
  @override
  _PaymentVerificationDialogState createState() =>
      _PaymentVerificationDialogState();
}

class _PaymentVerificationDialogState extends State<PaymentVerificationDialog> {
  bool _isVerified = true;
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isVerified ? Icons.check_circle : Icons.cancel,
            color: _isVerified ? Colors.green : Colors.red,
          ),
          SizedBox(width: 8),
          Text('Verify Payment'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment verification affects the booking status and tenant notification.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text('Approve Payment'),
                    leading: Radio<bool>(
                      value: true,
                      groupValue: _isVerified,
                      activeColor: Colors.green,
                      onChanged: (value) =>
                          setState(() => _isVerified = value!),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    dense: true,
                  ),
                  Divider(height: 1),
                  ListTile(
                    title: Text('Reject Payment'),
                    leading: Radio<bool>(
                      value: false,
                      groupValue: _isVerified,
                      activeColor: Colors.red,
                      onChanged: (value) =>
                          setState(() => _isVerified = value!),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    dense: true,
                  ),
                ],
              ),
            ),
            if (!_isVerified) ...[
              SizedBox(height: 16),
              Text(
                'Please provide a reason:',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason for rejection',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 3,
                validator: (value) {
                  if (!_isVerified && (value == null || value.trim().isEmpty)) {
                    return 'Please provide a reason for rejection';
                  }
                  return null;
                },
              ),
            ],
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
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'isVerified': _isVerified,
                'reason': _isVerified ? null : _reasonController.text,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _isVerified ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(_isVerified ? 'Approve' : 'Reject'),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
