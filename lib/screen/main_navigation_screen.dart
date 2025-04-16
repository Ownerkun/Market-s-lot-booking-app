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
import 'dart:math';

class MainNavigationScreen extends StatefulWidget {
  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context, listen: true);
    final screens = authProvider.userRole == 'LANDLORD'
        ? 4 // Number of screens for landlord
        : 2; // Number of screens for tenant
    if (_selectedIndex >= screens) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _selectedIndex = 0);
      });
    }
  }

  void _onNavItemTapped(int index, bool isLandlord) {
    final maxIndex = isLandlord ? 3 : 1;
    setState(() {
      _selectedIndex = min(index, maxIndex);
    });
  }

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
                  ProfileScreen(),
                ];

          // Validate and correct the selected index
          if (_selectedIndex >= screens.length) {
            _selectedIndex = 0;
          }

          return Scaffold(
            body: IndexedStack(
              index: min(_selectedIndex, screens.length - 1),
              children: screens,
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: min(_selectedIndex, screens.length - 1),
              onTap: (index) => _onNavItemTapped(index, isLandlord),
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Colors.grey,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.store),
                  label: 'Markets',
                ),
                if (isLandlord)
                  BottomNavigationBarItem(
                    icon: Icon(Icons.request_page),
                    label: 'Requests',
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
