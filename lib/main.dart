import 'package:flutter/material.dart';
import 'package:market_lot_app/screen/market_screen/market_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:provider/provider.dart';
import 'package:market_lot_app/auth_provider.dart';
import 'package:market_lot_app/screen/auth_screen/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final keyString = '12345678901234567890123456789012'; // 32-byte key
  final key = encrypt.Key.fromUtf8(keyString);
  final encrypter = encrypt.Encrypter(encrypt.AES(key));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              AuthProvider(prefs, encrypter), // Pass prefs and encrypter
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthScreen(),
      routes: {
        '/home': (context) => MarketListScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
