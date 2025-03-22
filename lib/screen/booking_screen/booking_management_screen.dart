import 'package:flutter/material.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:provider/provider.dart';

class LandlordBookingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Bookings'),
      ),
      body: bookingProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: bookingProvider.bookings.length,
              itemBuilder: (context, index) {
                final booking = bookingProvider.bookings[index];
                return ListTile(
                  title: Text('Booking for Lot: ${booking['lot']['name']}'),
                  subtitle: Text(
                      'Date: ${booking['date']} - Status: ${booking['status']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (booking['status'] == 'PENDING')
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () => bookingProvider.updateBookingStatus(
                              booking['id'], 'APPROVED'),
                        ),
                      if (booking['status'] == 'PENDING')
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () => bookingProvider.updateBookingStatus(
                              booking['id'], 'REJECTED'),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
