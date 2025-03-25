import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:provider/provider.dart';

class LandlordBookingsPage extends StatefulWidget {
  const LandlordBookingsPage({Key? key}) : super(key: key);

  @override
  _LandlordBookingsPageState createState() => _LandlordBookingsPageState();
}

class _LandlordBookingsPageState extends State<LandlordBookingsPage> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _isInitialized = false;
  Map<String, List<dynamic>> _pendingBookingsByMarket = {};
  Map<String, List<dynamic>> _historyBookingsByMarket = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _fetchAndGroupBookings();
    }
  }

  void _fetchAndGroupBookings() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);

      bookingProvider.fetchLandlordBookings().then((_) {
        print('Full booking data: ${jsonEncode(bookingProvider.bookings)}');
        _groupBookingsByMarket(bookingProvider.bookings);
      }).catchError((error) {
        print('Error fetching bookings: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load bookings')),
        );
      });
    });
  }

  void _groupBookingsByMarket(List<dynamic> bookings) {
    setState(() {
      _pendingBookingsByMarket = {};
      _historyBookingsByMarket = {};

      for (var booking in bookings) {
        try {
          final marketId = booking['lot']?['marketId'] ?? 'unknown';
          final marketName = 'Market ${marketId.substring(0, 8)}...';
          final status = booking['status'];

          if (status == 'PENDING') {
            if (!_pendingBookingsByMarket.containsKey(marketId)) {
              _pendingBookingsByMarket[marketId] = [];
            }
            _pendingBookingsByMarket[marketId]!.add({
              ...booking,
              'marketName': marketName,
            });
          } else {
            if (!_historyBookingsByMarket.containsKey(marketId)) {
              _historyBookingsByMarket[marketId] = [];
            }
            _historyBookingsByMarket[marketId]!.add({
              ...booking,
              'marketName': marketName,
            });
          }
        } catch (e) {
          print('Error processing booking: $e');
        }
      }
    });
  }

  Widget _buildBookingCard(dynamic booking, BuildContext context) {
    final status = booking['status'];
    final lotName = booking['lot']['name'];
    final date = booking['date'];
    final tenantEmail = booking['tenant']?['email'] ?? 'N/A';

    Color getStatusColor() {
      switch (status) {
        case 'PENDING':
          return Colors.orange.shade100;
        case 'APPROVED':
          return Colors.green.shade100;
        case 'REJECTED':
          return Colors.red.shade100;
        default:
          return Colors.grey.shade100;
      }
    }

    return Card(
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
              'Date: ${DateFormat('MMM d, yyyy').format(DateTime.parse(date))}',
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
                    onPressed: () {
                      final marketId = booking['lot']?['marketId'];
                      if (marketId != null) {
                        _updateBookingStatus(
                            booking['id'], 'APPROVED', marketId);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: Market ID not found')),
                        );
                      }
                    },
                    icon: Icon(Icons.check, color: Colors.white), // Icon color
                    label: Text(
                      'Approve',
                      style: TextStyle(color: Colors.white), // Text color
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white, // Add this line
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      final marketId = booking['lot']?['marketId'];
                      if (marketId != null) {
                        _updateBookingStatus(
                            booking['id'], 'REJECTED', marketId);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: Market ID not found')),
                        );
                      }
                    },
                    icon: Icon(Icons.close, color: Colors.white), // Icon color
                    label: Text(
                      'Reject',
                      style: TextStyle(color: Colors.white), // Text color
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white, // Add this line
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
          ],
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
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateBookingStatus(
      String bookingId, String status, String marketId) async {
    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);

    final success =
        await bookingProvider.updateBookingStatus(bookingId, status);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking $status successfully!'),
          backgroundColor: status == 'APPROVED' ? Colors.green : Colors.red,
        ),
      );
      // Refresh the data
      await bookingProvider.fetchLandlordBookings();
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
                    : _buildBookingsList(_pendingBookingsByMarket),

            // Booking History Tab
            bookingProvider.isLoading
                ? Center(child: CircularProgressIndicator())
                : _historyBookingsByMarket.isEmpty
                    ? _buildEmptyState('No booking history yet')
                    : _buildBookingsList(_historyBookingsByMarket),
          ],
        ),
      ),
    );
  }
}
