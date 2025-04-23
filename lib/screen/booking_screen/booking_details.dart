import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:market_lot_app/screen/payment/payment.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/provider/auth_provider.dart';

class ContractDetailScreen extends StatefulWidget {
  final Map<String, dynamic> contract;
  final bool isLandlordView;

  const ContractDetailScreen({
    Key? key,
    required this.contract,
    this.isLandlordView = false,
  }) : super(key: key);

  @override
  _ContractDetailScreenState createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  late Map<String, dynamic> tenant;
  bool isLoading = false;
  bool isProcessing = false;

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
      _showSnackBar('Failed to load tenant details: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _navigateToPayment() async {
    final lot = widget.contract['lot'];
    final startDate = DateTime.parse(widget.contract['startDate']);
    final endDate = DateTime.parse(widget.contract['endDate']);
    final duration = endDate.difference(startDate).inDays + 1;
    final totalPrice = (lot['price'] ?? 0.0) * duration * 1.0;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          bookingId: widget.contract['id'],
          amount: totalPrice,
        ),
      ),
    );

    if (result == true && mounted) {
      _showSnackBar('Payment submitted successfully!');
    }
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Cancellation'),
        content: Text('Are you sure you want to cancel this booking?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isProcessing = true);
    try {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      final success = await bookingProvider.updateBookingStatus(
        widget.contract['id'],
        'CANCELLED',
      );

      if (success && mounted) {
        _showSnackBar('Booking cancelled successfully');
        Navigator.pop(context, true);
      } else if (mounted) {
        _showSnackBar(
          bookingProvider.errorMessage ?? 'Failed to cancel booking',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error cancelling booking: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'PENDING':
        backgroundColor = Colors.orange.withOpacity(0.2);
        textColor = Colors.orange.shade800;
        break;
      case 'APPROVED':
        backgroundColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green.shade800;
        break;
      case 'REJECTED':
        backgroundColor = Colors.red.withOpacity(0.2);
        textColor = Colors.red.shade800;
        break;
      case 'CANCELLED':
        backgroundColor = Colors.grey.withOpacity(0.2);
        textColor = Colors.grey.shade800;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.2);
        textColor = Colors.grey.shade800;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.5), width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'PENDING':
        backgroundColor = Colors.orange.withOpacity(0.2);
        textColor = Colors.orange.shade800;
        icon = Icons.pending_actions;
        break;
      case 'PAID':
        backgroundColor = Colors.blue.withOpacity(0.2);
        textColor = Colors.blue.shade800;
        icon = Icons.payment;
        break;
      case 'VERIFIED':
        backgroundColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green.shade800;
        icon = Icons.verified;
        break;
      case 'REJECTED':
        backgroundColor = Colors.red.withOpacity(0.2);
        textColor = Colors.red.shade800;
        icon = Icons.error_outline;
        break;
      case 'EXPIRED':
        backgroundColor = Colors.grey.withOpacity(0.2);
        textColor = Colors.grey.shade800;
        icon = Icons.timer_off;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.2);
        textColor = Colors.grey.shade800;
        icon = Icons.help_outline;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentProofSection() {
    if (widget.contract['paymentProofUrl'] == null) return SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.green.shade700),
                SizedBox(width: 8),
                Text(
                  'Payment Proof',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: Text('Payment Proof'),
                            backgroundColor: Colors.green,
                          ),
                          body: Container(
                            color: Colors.black87,
                            child: Center(
                              child: InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 4.0,
                                child: Image.network(
                                  widget.contract['paymentProofUrl'],
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Hero(
                      tag: 'payment-proof-${widget.contract['id']}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.contract['paymentProofUrl'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.grey.shade100,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.green.shade300),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.grey.shade100,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 40, color: Colors.red.shade300),
                                  SizedBox(height: 8),
                                  Text('Error loading image',
                                      style: TextStyle(
                                          color: Colors.red.shade300)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.isLandlordView &&
                    widget.contract['paymentStatus'] == 'PAID') ...[
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.check_circle),
                          label: Text('Verify Payment'),
                          onPressed: () => _verifyPayment(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.cancel),
                          label: Text('Reject Payment'),
                          onPressed: () => _verifyPayment(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyPayment(bool isVerified) async {
    final reason = isVerified
        ? null
        : await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Reason for Rejection'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              content: TextField(
                decoration: InputDecoration(
                  hintText: 'Enter reason for rejecting payment',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 3,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final reason = (context as Element)
                        .findAncestorWidgetOfExactType<TextField>()
                        ?.controller
                        ?.text;
                    Navigator.pop(context, reason ?? 'Invalid payment');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Submit'),
                ),
              ],
            ),
          );

    if (!isVerified && reason == null) return;

    setState(() => isProcessing = true);
    try {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      final success = await bookingProvider.verifyPayment(
        widget.contract['id'],
        isVerified,
        reason: reason,
      );

      if (success && mounted) {
        _showSnackBar(
          isVerified ? 'Payment verified successfully' : 'Payment rejected',
          isError: !isVerified,
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
    Color? iconColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  Icon(icon, color: iconColor ?? Colors.green.shade700),
                if (icon != null) SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: iconColor ?? Colors.green.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime.parse(widget.contract['startDate']);
    final endDate = DateTime.parse(widget.contract['endDate']);
    final duration = endDate.difference(startDate).inDays + 1;
    final lot = widget.contract['lot'];
    final status = widget.contract['status']?.toString() ?? 'UNKNOWN';
    final paymentStatus =
        widget.contract['paymentStatus']?.toString() ?? 'PENDING';
    final totalPrice = (lot['price'] ?? 0.0) * duration;
    final canManage = status == 'PENDING' || status == 'APPROVED';

    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Details'),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          if (canManage)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                _showSnackBar('Refreshing booking details...');
                // Refresh logic could be added here
              },
            ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Container(
                  color: Colors.grey.shade50,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with status badges
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.receipt,
                                            color: Colors.green.shade700),
                                        SizedBox(width: 8),
                                        Text(
                                          'Booking #${widget.contract['id']?.toString().substring(0, 8) ?? 'N/A'}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    _buildStatusBadge(status),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Divider(
                                  color: Colors.grey.shade300,
                                  thickness: 1,
                                ),
                                SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Payment Status:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    _buildPaymentBadge(paymentStatus),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Booking Summary
                        _buildSectionCard(
                          title: 'Booking Summary',
                          icon: Icons.calendar_today,
                          children: [
                            _buildDetailRow('Lot Name:', lot['name']),
                            _buildDetailRow('Market:', lot['market']['name']),
                            _buildDetailRow('Dates:',
                                '${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}'),
                            _buildDetailRow('Duration:',
                                '$duration day${duration > 1 ? 's' : ''}'),
                            _buildDetailRow('Daily Price:',
                                '${NumberFormat('#,##0.00').format(lot['price'] ?? 0.0)} THB'),
                            Divider(color: Colors.grey.shade300),
                            _buildDetailRow(
                              'Total Amount:',
                              '${NumberFormat('#,##0.00').format(totalPrice)} THB',
                              isBold: true,
                              textColor: Colors.green.shade700,
                            ),
                          ],
                        ),

                        // Tenant Information
                        _buildSectionCard(
                          title: 'Tenant Information',
                          icon: Icons.person,
                          children: [
                            _buildContactDetailRow(
                              'Name:',
                              tenant['name'],
                              Icons.person,
                            ),
                            _buildContactDetailRow(
                              'Email:',
                              tenant['email'],
                              Icons.email,
                            ),
                            _buildContactDetailRow(
                              'Phone:',
                              tenant['phone'],
                              Icons.phone,
                            ),
                          ],
                        ),

                        // Payment Information (if available)
                        if (widget.contract['paymentMethod'] != null)
                          _buildSectionCard(
                            title: 'Payment Details',
                            icon: Icons.payment,
                            children: [
                              _buildDetailRow(
                                  'Method:', widget.contract['paymentMethod']),
                              if (widget.contract['paymentDate'] != null)
                                _buildDetailRow(
                                    'Date:',
                                    DateFormat('MMM d, yyyy - hh:mm a').format(
                                        DateTime.parse(
                                            widget.contract['paymentDate']))),
                              if (widget.contract['paymentVerifiedBy'] != null)
                                _buildDetailRow('Verified By:',
                                    widget.contract['paymentVerifiedBy']),
                            ],
                          ),

                        // Payment Proof Section
                        if (widget.contract['paymentProofUrl'] != null)
                          _buildPaymentProofSection(),

                        SizedBox(height: 100), // Space for bottom buttons
                      ],
                    ),
                  ),
                ),

                // Bottom action buttons
                if (canManage)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, -5),
                          ),
                        ],
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            if (status == 'PENDING')
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: Icon(Icons.cancel),
                                  label: Text('Cancel Booking'),
                                  onPressed:
                                      isProcessing ? null : _cancelBooking,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: BorderSide(color: Colors.red),
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            if (status == 'PENDING') SizedBox(width: 16),
                            if (paymentStatus != 'VERIFIED' &&
                                paymentStatus != 'PAID')
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.payment),
                                  label: Text('Make Payment'),
                                  onPressed: _navigateToPayment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false, Color? textColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: textColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          SizedBox(width: 8),
          SizedBox(
            width: 80,
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
