import 'package:flutter/material.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

class BookingRequestPage extends StatefulWidget {
  final String lotId;
  final String marketId;

  const BookingRequestPage(
      {Key? key,
      required this.lotId,
      required this.marketId,
      required DateTime selectedDate})
      : super(key: key);

  @override
  _BookingRequestPageState createState() => _BookingRequestPageState();
}

class _BookingRequestPageState extends State<BookingRequestPage> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Request Booking'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Select Date',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(Duration(days: 365)),
              focusedDay: _selectedDate,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDate = selectedDay;
                });
              },
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                await bookingProvider.requestBooking(
                    widget.lotId, _selectedDate);
                if (bookingProvider.errorMessage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Booking requested successfully!')),
                  );
                  Navigator.pop(context); // Close the booking request page
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(bookingProvider.errorMessage!)),
                  );
                }
              },
              child: Text('Submit Booking Request'),
            ),
          ],
        ),
      ),
    );
  }
}
