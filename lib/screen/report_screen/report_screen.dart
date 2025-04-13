import 'package:flutter/material.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/provider/market_provider.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class MarketReportScreen extends StatefulWidget {
  @override
  _MarketReportScreenState createState() => _MarketReportScreenState();
}

class _MarketReportScreenState extends State<MarketReportScreen> {
  int _selectedPeriod = 30;
  bool _isLoading = false;
  String? _selectedMarketId;
  List<Map<String, dynamic>> _landlordMarkets = [];
  late BookingProvider _bookingProvider;
  late MarketProvider _marketProvider;

  List<Map<String, dynamic>> get displayedBookings {
    final bookings = _selectedMarketId == null
        ? _bookingProvider.bookings
        : _bookingProvider.bookings
            .where((b) => b['lot']?['marketId'] == _selectedMarketId)
            .toList();

    return bookings.cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get displayedLots => _selectedMarketId == null
      ? _marketProvider.lots
      : _marketProvider.lots
          .where((lot) => lot['marketId'] == _selectedMarketId)
          .toList();

  @override
  void initState() {
    super.initState();
    _bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    _marketProvider = Provider.of<MarketProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      final marketProvider =
          Provider.of<MarketProvider>(context, listen: false);

      // Always load markets first
      await authProvider.fetchMarkets();
      _landlordMarkets = authProvider.markets;

      // Load bookings - filtered by selected market if specified
      await bookingProvider.fetchLandlordBookings(marketId: _selectedMarketId);

      // Only fetch lots if a specific market is selected
      if (_selectedMarketId != null) {
        // Create a new MarketProvider instance for the selected market
        final specificMarketProvider =
            MarketProvider(_selectedMarketId!, authProvider);
        await specificMarketProvider.fetchLots(context);
        // Update the main market provider's data
        _marketProvider = specificMarketProvider;
      } else {
        // For "All Markets", we don't need to fetch lots (or fetch all if needed)
        _marketProvider.lots.clear(); // Clear previous market's lots
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMarketDropdown() {
    return DropdownButton<String>(
      value: _selectedMarketId,
      hint: Text('All Markets'),
      onChanged: (String? newValue) async {
        setState(() => _selectedMarketId = newValue);
        await _loadData(); // Reload data when market changes
      },
      items: [
        DropdownMenuItem(
          value: null,
          child: Text('All Markets'),
        ),
        ..._landlordMarkets.map((market) {
          return DropdownMenuItem(
            value: market['id'],
            child: Text(market['name']),
          );
        }),
      ],
    );
  }

  Map<String, dynamic> _calculateMetrics() {
    final bookings = displayedBookings;
    final lots = _selectedMarketId == null ? [] : _marketProvider.lots;

    final approvedBookings = bookings
        .where((b) => b['status']?.toString().toUpperCase() == 'APPROVED')
        .length;

    final totalLots = lots.length;
    final occupiedLotIds = bookings
        .where((b) => b['status']?.toString().toUpperCase() == 'APPROVED')
        .map((b) => b['lot']?['id'])
        .whereType<String>()
        .toSet();

    final occupiedLots = lots
        .where((lot) =>
            occupiedLotIds.contains(lot['id']) || lot['available'] == false)
        .length;

    final occupancyRate = totalLots > 0 ? (occupiedLots / totalLots * 100) : 0;

    final totalRevenue = bookings.fold(0.0, (sum, booking) {
      if (booking['status']?.toString().toUpperCase() == 'APPROVED') {
        final price = (booking['lot']?['price'] as num?)?.toDouble() ?? 0;
        final days = DateTime.parse(booking['endDate'])
                .difference(DateTime.parse(booking['startDate']))
                .inDays +
            1;
        return sum + (price * days);
      }
      return sum;
    });

    return {
      'totalLots': totalLots,
      'occupiedLots': occupiedLots,
      'occupancyRate': occupancyRate,
      'approvedBookings': approvedBookings,
      'totalRevenue': totalRevenue,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Market Report'),
        actions: [
          _buildMarketDropdown(),
          PopupMenuButton<int>(
            onSelected: (days) => setState(() => _selectedPeriod = days),
            itemBuilder: (context) => [
              PopupMenuItem(value: 7, child: Text('Last 7 days')),
              PopupMenuItem(value: 30, child: Text('Last 30 days')),
              PopupMenuItem(value: 90, child: Text('Last 90 days')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDebugView(),
                  _buildSummaryCards(),
                  SizedBox(height: 24),
                  _buildBookingTrends(),
                  SizedBox(height: 24),
                  _buildBookingStatusDistribution(),
                  SizedBox(height: 24),
                  _buildTopPerformingLots(),
                  SizedBox(height: 24),
                  _buildRevenueChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildDebugView() {
    return ExpansionTile(
      title: Text('Debug Data'),
      children: [
        Text('Selected Market: ${_selectedMarketId ?? "All Markets"}'),
        Text('Lots Count: ${_marketProvider.lots.length}'),
        Text('Filtered Bookings Count: ${displayedBookings.length}'),
        if (displayedBookings.isNotEmpty) ...[
          Text('First Booking Lot: ${displayedBookings.first['lot']?['name']}'),
          Text(
              'First Booking Market: ${displayedBookings.first['lot']?['market']?['name']}'),
          Text('First Booking Status: ${displayedBookings.first['status']}'),
        ],
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        return Consumer<MarketProvider>(
          builder: (context, marketProvider, child) {
            final metrics = _calculateMetrics();

            return GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildSummaryCard('Total Lots', metrics['totalLots'].toString(),
                    Icons.grid_view, Colors.blue),
                _buildSummaryCard(
                    'Occupancy Rate',
                    '${metrics['occupancyRate'].toStringAsFixed(1)}%',
                    Icons.person,
                    Colors.green),
                _buildSummaryCard(
                    'Available Lots',
                    (metrics['totalLots'] - metrics['occupiedLots']).toString(),
                    Icons.check_circle,
                    Colors.orange),
                _buildSummaryCard(
                    'Approved Bookings',
                    metrics['approvedBookings'].toString(),
                    Icons.check_circle_outline,
                    Colors.green),
                _buildSummaryCard(
                    'Total Revenue',
                    '\$${metrics['totalRevenue'].toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.purple),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingTrends() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Trends',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: LineChart(
                // Implement line chart data here
                LineChartData(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingStatusDistribution() {
    final bookingProvider = Provider.of<BookingProvider>(context);

    final statusCounts = {
      'Approved': bookingProvider.bookings
          .where((b) => b['status'] == 'APPROVED')
          .length,
      'Pending': bookingProvider.bookings
          .where((b) => b['status'] == 'PENDING')
          .length,
      'Rejected': bookingProvider.bookings
          .where((b) => b['status'] == 'REJECTED')
          .length,
      'Cancelled': bookingProvider.bookings
          .where((b) => b['status'] == 'CANCELLED')
          .length,
    };

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Status Distribution',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: statusCounts.entries.map((e) {
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      title: '${e.key}\n${e.value}',
                      color: _getStatusColor(e.key),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Rejected':
        return Colors.red;
      case 'Cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Widget _buildTopPerformingLots() {
    final marketProvider = Provider.of<MarketProvider>(context);
    final lots = marketProvider.lots;

    // Sort lots by revenue or occupancy
    final sortedLots = [...lots]
      ..sort((a, b) => (b['revenue'] ?? 0).compareTo(a['revenue'] ?? 0));

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Lots',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: sortedLots.take(5).length,
              itemBuilder: (context, index) {
                final lot = sortedLots[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(lot['name']),
                  subtitle: Text('Revenue: \$${lot['revenue'] ?? 0}'),
                  trailing: Icon(Icons.trending_up, color: Colors.green),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: BarChart(
                // Implement bar chart data here
                BarChartData(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
