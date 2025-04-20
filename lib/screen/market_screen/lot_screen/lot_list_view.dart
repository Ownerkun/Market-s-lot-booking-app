import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                                  'THB ${lot['price'].toStringAsFixed(2)}',
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
                                                final authProvider =
                                                    Provider.of<AuthProvider>(
                                                        context,
                                                        listen: false);

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

                                                // Refresh lots after successful update
                                                await marketProvider
                                                    .fetchLots(context);

                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .check_circle,
                                                              color:
                                                                  Colors.white),
                                                          SizedBox(width: 8),
                                                          Text(
                                                              'Lot updated successfully'),
                                                        ],
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                      duration:
                                                          Duration(seconds: 2),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .error_outline,
                                                              color:
                                                                  Colors.white),
                                                          SizedBox(width: 8),
                                                          Expanded(
                                                              child: Text(
                                                                  'Failed to update lot: $e')),
                                                        ],
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                      duration:
                                                          Duration(seconds: 3),
                                                    ),
                                                  );
                                                }
                                                print(
                                                    'Error updating lot: $e'); // For debugging
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

    final nameController = TextEditingController(text: lot['name']);
    final detailsController = TextEditingController(text: lot['details']);
    final priceController =
        TextEditingController(text: lot['price'].toString());
    final widthController = TextEditingController(
        text: (lot['size'].width * 100).toStringAsFixed(0) // Convert to cm
        );
    final heightController = TextEditingController(
        text: (lot['size'].height * 100).toStringAsFixed(0) // Convert to cm
        );
    bool isAvailable = lot['available'] ?? false;

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
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
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
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
                    Row(
                      children: [
                        Icon(Icons.edit_location, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Edit Lot Details',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Name field
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.edit),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Details field
                    TextField(
                      controller: detailsController,
                      decoration: InputDecoration(
                        labelText: 'Details',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: 16),
                    // Price field
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Size fields
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: widthController,
                            decoration: InputDecoration(
                              labelText: 'Width (cm)',
                              helperText: 'Min: 150cm',
                              errorText:
                                  (double.tryParse(widthController.text) ?? 0) <
                                          150
                                      ? 'Minimum 150cm'
                                      : null,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixIcon: Icon(Icons.width_normal),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: heightController,
                            decoration: InputDecoration(
                              labelText: 'Height (cm)',
                              helperText: 'Min: 150cm',
                              errorText:
                                  (double.tryParse(heightController.text) ??
                                              0) <
                                          150
                                      ? 'Minimum 150cm'
                                      : null,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixIcon: Icon(Icons.height),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Availability toggle
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Available for rent'),
                        Spacer(),
                        Switch(
                          value: isAvailable,
                          onChanged: (value) =>
                              setState(() => isAvailable = value),
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel'),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600]),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              final width = double.parse(widthController.text);
                              final height =
                                  double.parse(heightController.text);
                              final price = double.parse(priceController.text);

                              if (width < 150 || height < 150) {
                                throw 'Minimum size is 150cm x 150cm';
                              }

                              if (price <= 0) {
                                throw 'Price must be greater than 0';
                              }

                              final success = await marketProvider.updateLot(
                                index: index,
                                name: nameController.text,
                                details: detailsController.text,
                                price: price,
                                available: isAvailable,
                                size: Size(width / 100,
                                    height / 100), // Convert back to meters
                                context: context,
                              );

                              if (success && context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: Colors.white),
                                      SizedBox(width: 8),
                                      Expanded(child: Text(e.toString())),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
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
        ),
      );
    } finally {
      // Dispose controllers
      nameController.dispose();
      detailsController.dispose();
      priceController.dispose();
      widthController.dispose();
      heightController.dispose();
    }
  }
}
