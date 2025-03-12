import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:market_lot_app/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class MarketCreationWizard extends StatefulWidget {
  @override
  _MarketCreationWizardState createState() => _MarketCreationWizardState();
}

class _MarketCreationWizardState extends State<MarketCreationWizard> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Form fields
  String _name = '';
  String _type = '';
  String _location = '';

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Save all form fields
    _formKey.currentState!.save();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Debugging: Log the token
      final token = await authProvider.getToken();
      print('Token: $token'); // Debugging

      if (token == null) {
        throw Exception('No token found. Please log in.');
      }

      // Debugging: Log the request body
      final body = json.encode({
        'name': _name,
        'type': _type,
        'location': _location,
      });
      print('Request Body: $body'); // Debugging

      final response = await http.post(
        Uri.parse('http://localhost:3002/markets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      // Debugging: Log the API response
      print('Response Status Code: ${response.statusCode}'); // Debugging
      print('Response Body: ${response.body}'); // Debugging

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Market created successfully!')),
        );
        await authProvider.fetchMarkets(); // Refresh the market list
        Navigator.of(context).pop(); // Close the wizard
      } else {
        // Handle specific error cases
        final errorMessage =
            json.decode(response.body)['message'] ?? 'Failed to create market.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please try again.')),
      );
      print('Error: $e'); // Debugging
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Market'),
      ),
      body: Form(
        key: _formKey, // Apply the form key to the parent widget
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() {
                _currentStep += 1;
              });
            } else {
              _submit();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep -= 1;
              });
            }
          },
          steps: [
            Step(
              title: Text('Market Name'),
              content: TextFormField(
                decoration: InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a market name.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _name = value!;
                },
              ),
            ),
            Step(
              title: Text('Market Type'),
              content: TextFormField(
                decoration: InputDecoration(labelText: 'Type'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a market type.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _type = value!;
                },
              ),
            ),
            Step(
              title: Text('Market Location'),
              content: TextFormField(
                decoration: InputDecoration(labelText: 'Location'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a market location.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _location = value!;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
