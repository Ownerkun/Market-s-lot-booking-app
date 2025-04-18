import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:provider/provider.dart';

class ContractDetailScreen extends StatefulWidget {
  final Map<String, dynamic> contract;

  const ContractDetailScreen({Key? key, required this.contract})
      : super(key: key);

  @override
  _ContractDetailScreenState createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  late Map<String, dynamic> tenant;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    tenant = widget.contract['tenant'] ??
        {'name': 'Loading...', 'email': 'N/A', 'phone': 'N/A'};

    if (widget.contract['tenantId'] != null && tenant['name'] == 'Loading...') {
      _fetchTenantDetails();
    }
  }

  Future<void> _fetchTenantDetails() async {
    setState(() => isLoading = true);
    try {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      final tenantDetails =
          await bookingProvider.fetchTenantDetails(widget.contract['tenantId']);
      setState(() {
        tenant = {
          'name': tenantDetails['name'] ?? 'Unknown Tenant',
          'email': tenantDetails['email'] ?? 'N/A',
          'phone': tenantDetails['phone'] ?? 'N/A',
        };
      });
    } catch (e) {
      setState(() {
        tenant = {'name': 'Unknown Tenant', 'email': 'N/A', 'phone': 'N/A'};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load tenant details: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime.parse(widget.contract['startDate']);
    final endDate = DateTime.parse(widget.contract['endDate']);
    final lot = widget.contract['lot'];
    final status = widget.contract['status'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Contract Details'),
        backgroundColor: Colors.green,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Contract Information', [
                    _buildDetailRow('Status', status),
                    _buildDetailRow('Contract ID', widget.contract['id']),
                    _buildDetailRow('Start Date',
                        DateFormat('MMM d, yyyy').format(startDate)),
                    _buildDetailRow(
                        'End Date', DateFormat('MMM d, yyyy').format(endDate)),
                  ]),
                  SizedBox(height: 24),
                  _buildSection('Lot Information', [
                    _buildDetailRow('Lot Name', lot['name']),
                    _buildDetailRow('Market', lot['market']['name']),
                    _buildDetailRow(
                        'Description', lot['description'] ?? 'No description'),
                  ]),
                  SizedBox(height: 24),
                  _buildSection('Tenant Information', [
                    _buildDetailRow('Name', tenant['name'] ?? 'N/A'),
                    _buildDetailRow('Email', tenant['email'] ?? 'N/A'),
                    _buildDetailRow('Phone', tenant['phone'] ?? 'N/A'),
                  ]),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
        SizedBox(height: 12),
        Card(
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
