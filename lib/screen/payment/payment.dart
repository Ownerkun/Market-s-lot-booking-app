import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:market_lot_app/provider/booking_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final double amount;

  const PaymentScreen({
    Key? key,
    required this.bookingId,
    required this.amount,
  }) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _paymentMethodController = TextEditingController();
  File? _paymentProof;
  bool _isSubmitting = false;
  String? _selectedPaymentMethod;
  final List<String> _paymentMethods = ['Bank Transfer', 'QR Code', 'Cash'];

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = null;
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _paymentProof = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate() || _paymentProof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please fill all fields and select a payment proof')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final bookingProvider =
          Provider.of<BookingProvider>(context, listen: false);
      final success = await bookingProvider.submitPaymentProof(
        widget.bookingId,
        _paymentMethodController.text,
        _paymentProof!, // Pass the File object directly
      );

      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment submitted successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  bookingProvider.errorMessage ?? 'Payment submission failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting payment: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Submit Payment'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Amount: ${NumberFormat('#,##0.00').format(widget.amount)} THB',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: _paymentMethods.map((String method) {
                  return DropdownMenuItem<String>(
                    value: method,
                    child: Text(method),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPaymentMethod = newValue;
                    _paymentMethodController.text = newValue ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a payment method';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Text(
                'Payment Proof',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              if (_paymentProof != null)
                Column(
                  children: [
                    Image.file(
                      _paymentProof!,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                    SizedBox(height: 8),
                    TextButton(
                      onPressed: _pickImage,
                      child: Text('Change Image'),
                    ),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: _pickImage,
                  child: Text('Select Payment Proof'),
                ),
              SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPayment,
                  child: _isSubmitting
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Submit Payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _paymentMethodController.dispose();
    super.dispose();
  }
}
