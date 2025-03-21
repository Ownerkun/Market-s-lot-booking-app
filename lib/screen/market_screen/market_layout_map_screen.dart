import 'package:flutter/material.dart';
import 'package:market_lot_app/auth_provider.dart';
import 'package:market_lot_app/market_provider.dart';
import 'package:market_lot_app/screen/market_screen/lot_screen/lot_list_view.dart';
import 'package:market_lot_app/screen/market_screen/market_map_view.dart';
import 'package:provider/provider.dart';

class MarketLayoutScreen extends StatefulWidget {
  final String marketId;

  MarketLayoutScreen({required this.marketId});

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
    final marketProvider = Provider.of<MarketProvider>(context, listen: false);
    marketProvider.init(context);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          marketProvider.marketInfo != null
              ? '${marketProvider.marketInfo!['name']} Layout'
              : 'Market Layout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFFC0F8C0),
        actions: [
          IconButton(
            icon: Icon(
              _isListView ? Icons.map_outlined : Icons.list,
              color: Colors.black87,
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
      body: marketProvider.isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading market layout...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: _isListView ? MarketListView() : MarketMapView(),
            ),
      floatingActionButton: isLandlord
          ? FloatingActionButton.extended(
              onPressed: () => marketProvider.addLot(context),
              label: Text(_isListView ? 'Add Lot' : 'Add Space'),
              icon: Icon(Icons.add),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }
}
