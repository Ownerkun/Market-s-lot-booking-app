import 'package:flutter/material.dart';

class AdminDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.people),
            title: Text('User Management'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          // ListTile(
          //   leading: Icon(Icons.store),
          //   title: Text('Market Management'),
          //   onTap: () {
          //     // TODO: Navigate to market management
          //     Navigator.pop(context);
          //   },
          // ),
        ],
      ),
    );
  }
}
