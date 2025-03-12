import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:market_lot_app/screen/market_screen/market_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:provider/provider.dart';
import 'package:market_lot_app/auth_provider.dart';
import 'package:market_lot_app/screen/auth_screen/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final keyString = dotenv.env['ENCRYPTION_KEY'] ?? '';

  if (keyString.isEmpty) {
    throw Exception("Encryption key not found in .env file");
  }

  final prefs = await SharedPreferences.getInstance();
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
    );
  }
}
