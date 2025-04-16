import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ContractDetailScreen extends StatelessWidget {
  final Map<String, dynamic> contract;

  const ContractDetailScreen({Key? key, required this.contract})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime.parse(contract['startDate']);
    final endDate = DateTime.parse(contract['endDate']);
    final tenant = contract['tenant'];
    final lot = contract['lot'];
    final status = contract['status'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Contract Details'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Contract Information', [
              _buildDetailRow('Status', status),
              _buildDetailRow('Contract ID', contract['id']),
              _buildDetailRow(
                  'Start Date', DateFormat('MMM d, yyyy').format(startDate)),
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
