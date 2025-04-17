import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/screen/booking_screen/booking_details.dart';

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
  Map<String, List<dynamic>> _pendingBookingsByMarket = {};
  Map<String, List<dynamic>> _historyBookingsByMarket = {};

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
        print('Full booking data: ${jsonEncode(bookingProvider.bookings)}');
        _groupBookingsByMarket(bookingProvider.bookings);
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

  void _groupBookingsByMarket(List<dynamic> bookings) {
    if (!mounted) return;

    try {
      final pending = <String, List<dynamic>>{};
      final history = <String, List<dynamic>>{};

      for (var booking in bookings) {
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

          final bookingWithDates = {
            ...booking,
            'marketName': marketName,
            'startDate': booking['startDate'],
            'endDate': booking['endDate'],
            'processedAt': DateTime.now().toIso8601String(), // For debugging
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
          continue; // Skip this booking but continue processing others
        }
      }

      // Sort bookings by date
      for (var marketBookings in [...pending.values, ...history.values]) {
        marketBookings.sort((a, b) {
          final aDate = DateTime.parse(a['startDate']);
          final bDate = DateTime.parse(b['startDate']);
          return bDate.compareTo(aDate); // Most recent first
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

  Widget _buildBookingCard(dynamic booking, BuildContext context) {
    final status = booking['status'];
    final lotName = booking['lot']['name'];
    final startDate = DateTime.parse(booking['startDate']);
    final endDate = DateTime.parse(booking['endDate']);
    final tenantEmail = booking['tenant']?['email'] ?? 'N/A';

    final duration = endDate.difference(startDate).inDays + 1;

    Color getStatusColor() {
      switch (status) {
        case 'PENDING':
          return Colors.orange.shade100;
        case 'APPROVED':
          return Colors.green.shade100;
        case 'REJECTED':
          return Colors.red.shade100;
        case 'CANCELLED':
          return Colors.grey.shade100;
        default:
          return Colors.grey.shade100;
      }
    }

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
                'market':
                    booking['lot']['market'] ?? {'name': 'Unknown Market'},
              },
              'tenant': booking['tenant'] ??
                  {'name': 'Unknown Tenant', 'email': 'N/A', 'phone': 'N/A'},
              'startDate': booking['startDate'],
              'endDate': booking['endDate'],
            }),
          ),
        );
      },
      child: Card(
        elevation: 4,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: getStatusColor(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lot: $lotName',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getStatusChipColor(status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Dates: ${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
                style: TextStyle(color: Colors.black87),
              ),
              Text(
                'Duration: $duration day${duration > 1 ? 's' : ''}',
                style: TextStyle(color: Colors.black87),
              ),
              Text(
                'Tenant: $tenantEmail',
                style: TextStyle(color: Colors.black87),
              ),
              SizedBox(height: 12),
              if (status == 'PENDING')
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
                                final marketId = booking['lot']?['marketId'];
                                if (marketId != null) {
                                  _updateBookingStatus(
                                      booking['id'], 'APPROVED', marketId);
                                }
                              }
                            },
                      icon: _isUpdating
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.check, color: Colors.white),
                      label: Text(
                        'Approve',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isUpdating
                          ? null
                          : () async {
                              final reason = await showDialog<String>(
                                context: context,
                                builder: (context) => RejectionReasonDialog(),
                              );
                              if (reason != null) {
                                final marketId = booking['lot']?['marketId'];
                                if (marketId != null) {
                                  _updateBookingStatus(
                                      booking['id'], 'REJECTED', marketId);
                                }
                              }
                            },
                      icon: _isUpdating
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.close, color: Colors.white),
                      label: Text(
                        'Reject',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              if (status == 'APPROVED')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
                        icon: _isUpdating
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Icon(Icons.cancel_outlined, color: Colors.white),
                        label: Text('Cancel Booking',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
      String bookingId, String status, String marketId) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);

      // Handle rejection reason
      String? reason;
      if (status == 'REJECTED') {
        reason = await showDialog<String>(
          context: context,
          builder: (context) => RejectionReasonDialog(),
        );
        if (reason == null) {
          setState(() => _isUpdating = false);
          return;
        }
      }

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

        // Refresh data
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

        _groupBookingsByMarket(bookingProvider.bookings);
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

  // Add this helper method to get appropriate status colors
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Booking Management'),
          backgroundColor: Colors.green,
          elevation: 0,
          bottom: TabBar(
            tabs: [
              Tab(text: 'Pending Requests'),
              Tab(text: 'Booking History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Pending Requests Tab
            bookingProvider.isLoading
                ? Center(child: CircularProgressIndicator())
                : _pendingBookingsByMarket.isEmpty
                    ? _buildEmptyState('No pending booking requests')
                    : RefreshIndicator(
                        onRefresh: () async {
                          await bookingProvider.fetchLandlordBookings();
                          _groupBookingsByMarket(bookingProvider.bookings);
                        },
                        child: _buildBookingsList(_pendingBookingsByMarket),
                      ),

            // Booking History Tab
            bookingProvider.isLoading
                ? Center(child: CircularProgressIndicator())
                : _historyBookingsByMarket.isEmpty
                    ? _buildEmptyState('No booking history yet')
                    : RefreshIndicator(
                        onRefresh: () async {
                          await bookingProvider.fetchLandlordBookings();
                          _groupBookingsByMarket(bookingProvider.bookings);
                        },
                        child: _buildBookingsList(_historyBookingsByMarket),
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
