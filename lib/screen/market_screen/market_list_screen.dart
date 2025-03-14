import 'package:flutter/material.dart';
import 'package:market_lot_app/screen/market_screen/lot_screen/market_layout_map_screen.dart';
import 'package:market_lot_app/screen/market_screen/market_create_screen.dart';
import 'package:market_lot_app/screen/profile/edit_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/auth_provider.dart';

class SideMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blueAccent,
            ),
            accountName: Text(
              "${authProvider.userProfile?['firstName'] ?? 'Profile'} ${authProvider.userProfile?['lastName'] ?? ''}",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(authProvider.userRole ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.blueAccent),
            ),
          ),
          _buildDrawerItem(Icons.settings, 'Settings', () {}),
          _buildDrawerItem(Icons.edit, 'Edit Profile', () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => EditProfileScreen()),
            );
          }),
          Spacer(),
          _buildDrawerItem(Icons.logout, 'Logout', () {
            authProvider.logout();
            Navigator.of(context).pushReplacementNamed('/');
          }),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(title, style: TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }
}

class MarketListScreen extends StatefulWidget {
  @override
  _MarketListScreenState createState() => _MarketListScreenState();
}

class _MarketListScreenState extends State<MarketListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.fetchMarkets();
      authProvider.fetchProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Markets',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: SideMenu(),
      body: authProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : authProvider.markets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No markets available',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      if (authProvider.userRole == 'LANDLORD')
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => MarketCreationWizard(),
                              ),
                            );
                          },
                          child: Text('Create a Market'),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  itemCount: authProvider.markets.length,
                  itemBuilder: (context, index) {
                    final market = authProvider.markets[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        title: Text(
                          market['name'],
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          market['location'],
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.blueAccent),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) =>
                                MarketLayoutScreen(marketId: market['id']),
                          ));
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: authProvider.userRole == 'LANDLORD'
          ? FloatingActionButton(
              backgroundColor: Colors.blueAccent,
              elevation: 5,
              tooltip: 'Add Market',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MarketCreationWizard(),
                  ),
                );
              },
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
