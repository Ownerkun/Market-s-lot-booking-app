import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ContractDetailScreen extends StatelessWidget {
  final Map<String, dynamic> contract;

  const ContractDetailScreen({Key? key, required this.contract})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contract Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              // Implement share functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildContractHeader(),
            _buildContractDetails(),
            _buildPartyDetails(),
            _buildPaymentDetails(),
            _buildTermsAndConditions(),
          ],
        ),
      ),
    );
  }

  Widget _buildContractHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.green.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contract #${contract['id']}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          _buildStatusChip(contract['status']),
        ],
      ),
    );
  }

  Widget _buildContractDetails() {
    final startDate = DateTime.parse(contract['startDate']);
    final endDate = DateTime.parse(contract['endDate']);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lot Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildDetailRow('Market', contract['lot']['market']['name']),
            _buildDetailRow('Lot Number', contract['lot']['name']),
            _buildDetailRow('Location', contract['lot']['location'] ?? 'N/A'),
            _buildDetailRow('Period',
                '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}'),
            _buildDetailRow(
                'Duration', '${endDate.difference(startDate).inDays + 1} days'),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyDetails() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Party Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildDetailRow('Tenant', contract['tenant']['name']),
            _buildDetailRow('Tenant Contact', contract['tenant']['phone']),
            _buildDetailRow(
                'Owner', contract['lot']['market']['owner']['name']),
            _buildDetailRow(
                'Owner Contact', contract['lot']['market']['owner']['phone']),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetails() {
    final price = contract['lot']['price'];
    final days = DateTime.parse(contract['endDate'])
            .difference(DateTime.parse(contract['startDate']))
            .inDays +
        1;
    final totalAmount = price * days;

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildDetailRow('Daily Rate', '\$${price.toStringAsFixed(2)}'),
            _buildDetailRow('Number of Days', days.toString()),
            Divider(),
            _buildDetailRow(
              'Total Amount',
              '\$${totalAmount.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms & Conditions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'By accepting this contract, both parties agree to the following terms:\n\n'
              '1. Payment must be made in full before the start date\n'
              '2. The lot must be kept clean and tidy\n'
              '3. Any damages must be reported immediately\n'
              '4. No subletting is allowed\n'
              '5. Operating hours must be followed',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'APPROVED':
        color = Colors.green;
        break;
      case 'PENDING':
        color = Colors.orange;
        break;
      case 'REJECTED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status,
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }
}
