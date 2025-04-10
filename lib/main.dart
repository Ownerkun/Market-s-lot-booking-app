// main.dart
import 'package:flutter/material.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:provider/provider.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'package:market_lot_app/screen/auth_screen/auth_screen.dart';
import 'package:market_lot_app/screen/main_navigation_screen.dart';
import 'package:market_lot_app/provider/market_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final keyString = '12345678901234567890123456789012'; // 32-byte key
  final key = encrypt.Key.fromUtf8(keyString);
  final encrypter = encrypt.Encrypter(encrypt.AES(key));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(prefs, encrypter)),
        ChangeNotifierProvider(
            create: (context) => MarketProvider('initial_market_id',
                Provider.of<AuthProvider>(context, listen: false))),
        ChangeNotifierProxyProvider<AuthProvider, BookingProvider>(
          create: (context) => BookingProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, authProvider, bookingProvider) =>
              BookingProvider(authProvider),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Market Booking App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          // This disables the default hero animation for FABs
          enableFeedback: true,
        ),
        fontFamily: 'Poppins',
        primaryColor: Colors.green,
        colorScheme: ColorScheme.light(primary: Colors.green),
        tabBarTheme: TabBarTheme(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              width: 2,
              color: Colors.white,
            ),
          ),
        ),
      ),
      home: AuthScreen(),
      routes: {
        '/home': (context) => MainNavigationScreen(),
      },
    );
  }
}
