import 'package:flutter/material.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'package:market_lot_app/provider/market_provider.dart';
import 'package:market_lot_app/screen/booking_screen/booking_management.dart';
import 'package:market_lot_app/screen/market_screen/lot_screen/lot_list_view.dart';
import 'package:market_lot_app/screen/market_screen/lot_screen/lot_map_view.dart';
import 'package:provider/provider.dart';

class MarketLayoutScreen extends StatefulWidget {
  final String marketId;

  const MarketLayoutScreen({Key? key, required this.marketId})
      : super(key: key);

  @override
  _MarketLayoutScreenState createState() => _MarketLayoutScreenState();
}

class _MarketLayoutScreenState extends State<MarketLayoutScreen>
    with SingleTickerProviderStateMixin {
  bool _isListView = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    // Initialize the MarketProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MarketProvider>(context, listen: false).init(context);
      _animationController.forward(); // Start the animation
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketProvider = Provider.of<MarketProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isLandlord = authProvider.userRole == 'LANDLORD';

    if (marketProvider.isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Loading market layout...',
                style: TextStyle(
                  color: Colors.green[800],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          marketProvider.marketInfo != null
              ? '${marketProvider.marketInfo!['name']} Layout'
              : 'Market Layout',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          if (isLandlord)
            IconButton(
              icon: Icon(Icons.request_page),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LandlordBookingsPage(),
                  ),
                );
              },
            ),
          IconButton(
            icon: Icon(
              _isListView ? Icons.map_outlined : Icons.list,
            ),
            onPressed: () {
              setState(() {
                _isListView = !_isListView;
                _animationController.reset();
                _animationController.forward();
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: FadeTransition(
            key: ValueKey(_isListView),
            opacity: _fadeAnimation,
            child: _isListView ? MarketListView() : MarketMapView(),
          ),
        ),
      ),
      floatingActionButton: isLandlord
          ? FloatingActionButton.extended(
              onPressed: () => marketProvider.addLot(context),
              label: Text(
                _isListView ? 'Add Lot' : 'Add Space',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              icon: Icon(Icons.add),
              backgroundColor: Colors.green[600],
              elevation: 4,
              heroTag: 'addLotButton',
            )
          : null,
    );
  }
}
