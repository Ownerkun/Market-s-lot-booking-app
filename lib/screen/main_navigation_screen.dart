// main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'package:market_lot_app/screen/booking_screen/booking_management_screen.dart';
import 'package:market_lot_app/screen/market_screen/market_list_screen.dart';
import 'package:market_lot_app/screen/profile/profile_screen.dart';
import 'package:provider/provider.dart';

class MainNavigationScreen extends StatefulWidget {
  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLandlord = authProvider.userRole == 'LANDLORD';

    // Define screens for both roles
    final List<Widget> landlordScreens = [
      MarketListScreen(),
      LandlordBookingsPage(),
      ProfileScreen(),
    ];

    final List<Widget> tenantScreens = [
      MarketListScreen(),
      // TenantBookingScreen(), // You'll need to implement this
      ProfileScreen(),
    ];

    final screens = isLandlord ? landlordScreens : tenantScreens;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.green,
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
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
