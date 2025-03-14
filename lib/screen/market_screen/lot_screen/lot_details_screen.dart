import 'package:flutter/material.dart';

class LotDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> lot;
  final String marketId;
  final Function(String, String, double) onSave;
  final bool isLandlord;

  LotDetailsScreen({
    required this.lot,
    required this.marketId,
    required this.onSave,
    required this.isLandlord,
  });

  void _showEditLotDialog(
      BuildContext context, Map<String, dynamic> lot) async {
    TextEditingController nameController =
        TextEditingController(text: lot['name']);
    TextEditingController detailsController =
        TextEditingController(text: lot['details']);
    TextEditingController priceController =
        TextEditingController(text: lot['price'].toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Lot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: detailsController,
                decoration: InputDecoration(labelText: 'Details'),
              ),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Save changes
                onSave(nameController.text, detailsController.text,
                    double.parse(priceController.text));
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lot Details'),
        actions: [
          if (isLandlord)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                _showEditLotDialog(context, lot);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Top Section: Image
          Container(
            height: MediaQuery.of(context).size.height * 0.3,
            child: Image.network(
              'https://picsum.photos/400/200',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 50,
                  ),
                );
              },
            ),
          ),
          // Middle Section: Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lot['name'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Price: \$${lot['price']}',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Details:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    lot['details'],
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Availability:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    lot['available'] ? 'Available' : 'Not Available',
                    style: TextStyle(
                      fontSize: 16,
                      color: lot['available'] ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Section: Book Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Handle booking logic here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Booking requested for ${lot['name']}')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                ),
                child: Text(
                  'Book Now',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
