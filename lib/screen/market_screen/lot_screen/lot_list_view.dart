import 'package:flutter/material.dart';
import 'package:market_lot_app/provider/market_provider.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:market_lot_app/screen/market_screen/lot_screen/lot_details_screen.dart';
import 'package:intl/intl.dart';

class MarketListView extends StatefulWidget {
  const MarketListView({Key? key}) : super(key: key);

  @override
  _MarketListViewState createState() => _MarketListViewState();
}

class _MarketListViewState extends State<MarketListView> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      // Refresh availability for the selected date
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      final marketProvider =
          Provider.of<MarketProvider>(context, listen: false);
      for (var lot in marketProvider.lots) {
        bookingProvider.refreshLotAvailability(lot['id']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketProvider = Provider.of<MarketProvider>(context);
    final lots = marketProvider.lots;
    final authProvider = Provider.of<AuthProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);
    final isLandlord = authProvider.userRole == 'LANDLORD';

    if (lots.isEmpty) {
      return _buildEmptyView(context, isLandlord);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.calendar_today),
              SizedBox(width: 10),
              Text(
                'Availability for:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 10),
              TextButton(
                onPressed: () => _selectDate(context),
                child: Text(
                  DateFormat('MMM d, yyyy').format(_selectedDate),
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: lots.length,
            itemBuilder: (context, index) {
              final lot = lots[index];
              final isAvailable = lot['available'] ?? false;
              final isDateAvailable =
                  bookingProvider.isDateAvailable(lot['id'], _selectedDate);
              final isDatePending =
                  bookingProvider.isDatePending(lot['id'], _selectedDate);

              return Card(
                margin: EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      Container(
                        color: _getLotColor(
                            isAvailable && isDateAvailable && !isDatePending),
                        height: 8,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.all(16),
                        title: Row(
                          children: [
                            Text(
                              lot['name'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(isAvailable,
                                    isDateAvailable, isDatePending),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _getStatusBorderColor(isAvailable,
                                      isDateAvailable, isDatePending),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _getStatusText(isAvailable, isDateAvailable,
                                    isDatePending),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusTextColor(isAvailable,
                                      isDateAvailable, isDatePending),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 8),
                            Text(
                              lot['details'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.monetization_on,
                                    size: 16, color: Colors.amber[700]),
                                SizedBox(width: 4),
                                Text(
                                  '\$${lot['price'].toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[700],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: Icon(Icons.visibility),
                                    label: Text('View Details'),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              LotDetailsScreen(
                                            lot: lot,
                                            isLandlord: isLandlord,
                                            marketId: marketProvider.marketId,
                                            selectedDate: _selectedDate,
                                            onSave: (name, detail, price,
                                                available) async {
                                              try {
                                                await authProvider.updateLot(
                                                  marketId:
                                                      marketProvider.marketId,
                                                  lotId: lot['id'],
                                                  name: name,
                                                  details: detail,
                                                  price: price,
                                                  available: available,
                                                  size: lot['size'],
                                                  position: lot['position'],
                                                );
                                                marketProvider
                                                    .fetchLots(context);
                                              } catch (e) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          'Failed to update lot: $e')),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue[700],
                                      side:
                                          BorderSide(color: Colors.blue[300]!),
                                    ),
                                  ),
                                ),
                                if (isLandlord) ...[
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.edit),
                                      label: Text('Edit'),
                                      onPressed: () {
                                        _showEditLotBottomSheet(context, index);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[700],
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getLotColor(bool isAvailable) {
    return isAvailable
        ? Color(0xFF4CAF50).withOpacity(0.7) // Green for available
        : Color(0xFFE57373).withOpacity(0.7); // Red for unavailable
  }

  Color _getStatusColor(
      bool isAvailable, bool isDateAvailable, bool isDatePending) {
    if (!isAvailable) return Colors.grey[100]!;
    if (isDatePending) return Colors.orange[50]!;
    if (!isDateAvailable) return Colors.red[50]!;
    return Colors.green[50]!;
  }

  Color _getStatusBorderColor(
      bool isAvailable, bool isDateAvailable, bool isDatePending) {
    if (!isAvailable) return Colors.grey;
    if (isDatePending) return Colors.orange;
    if (!isDateAvailable) return Colors.red;
    return Colors.green;
  }

  Color _getStatusTextColor(
      bool isAvailable, bool isDateAvailable, bool isDatePending) {
    if (!isAvailable) return Colors.grey[800]!;
    if (isDatePending) return Colors.orange[800]!;
    if (!isDateAvailable) return Colors.red[800]!;
    return Colors.green[800]!;
  }

  String _getStatusText(
      bool isAvailable, bool isDateAvailable, bool isDatePending) {
    if (!isAvailable) return 'Unavailable';
    if (isDatePending) return 'Pending';
    if (!isDateAvailable) return 'Booked';
    return 'Available';
  }

  Widget _buildEmptyView(BuildContext context, bool isLandlord) {
    final marketProvider = Provider.of<MarketProvider>(context, listen: false);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.space_dashboard_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No lots available in this market',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          if (isLandlord)
            ElevatedButton.icon(
              onPressed: () => marketProvider.addLot(context),
              icon: Icon(Icons.add),
              label: Text('Add First Lot'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  void _showEditLotBottomSheet(BuildContext context, int index) async {
    final marketProvider = Provider.of<MarketProvider>(context, listen: false);
    final lot = marketProvider.lots[index];

    TextEditingController nameController =
        TextEditingController(text: lot['name']);
    TextEditingController detailsController =
        TextEditingController(text: lot['details']);
    TextEditingController priceController =
        TextEditingController(text: lot['price'].toString());
    bool isAvailable = lot['available'] ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Edit Lot Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.edit),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: detailsController,
                      decoration: InputDecoration(
                        labelText: 'Details',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Available for rent:'),
                        Switch(
                          value: isAvailable,
                          onChanged: (value) {
                            setState(() {
                              isAvailable = value;
                            });
                          },
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                          ),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final success = await marketProvider.updateLot(
                              index: index,
                              name: nameController.text,
                              details: detailsController.text,
                              price: double.parse(priceController.text),
                              available: isAvailable,
                              context: context,
                            );

                            if (success) {
                              Navigator.pop(context);
                            }
                          },
                          child: Text('Save Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
