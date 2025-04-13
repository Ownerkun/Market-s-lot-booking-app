import 'package:flutter/material.dart';
import 'package:market_lot_app/screen/market_screen/market_create_screen.dart';
import 'package:market_lot_app/screen/report_screen/report_screen.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:market_lot_app/screen/booking_screen/booking_management_screen.dart';
import 'package:market_lot_app/screen/market_screen/market_list_screen.dart';
import 'package:market_lot_app/screen/profile/profile_screen.dart';
import 'package:market_lot_app/provider/market_provider.dart';

class MainNavigationScreen extends StatefulWidget {
  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  void _navigateToMarketCreation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: Provider.of<MarketProvider>(context, listen: false),
          child: MarketCreationWizard(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProxyProvider<AuthProvider, BookingProvider>(
          create: (context) => BookingProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, auth, previousBooking) {
            return previousBooking?.update(auth) ?? BookingProvider(auth);
          },
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final isLandlord = authProvider.userRole == 'LANDLORD';

          final List<Widget> screens = isLandlord
              ? [
                  MarketListScreen(),
                  LandlordBookingsPage(),
                  MarketReportScreen(),
                  ProfileScreen(),
                ]
              : [
                  MarketListScreen(),
                  //TenantBookingScreen(),
                  ProfileScreen(),
                ];

          return Scaffold(
            body: IndexedStack(
              index: _selectedIndex,
              children: screens,
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Colors.grey,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.store),
                  label: 'Markets',
                ),
                BottomNavigationBarItem(
                  icon: Icon(isLandlord ? Icons.request_page : Icons.book),
                  label: isLandlord ? 'Requests' : 'My Bookings',
                ),
                if (isLandlord)
                  BottomNavigationBarItem(
                    icon: Icon(Icons.analytics),
                    label: 'Reports',
                  ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
