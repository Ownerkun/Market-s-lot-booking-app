import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:market_lot_app/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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
  LatLng? _selectedLocation;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _markers.clear();
      _markers.add(Marker(
        markerId: MarkerId('selected_location'),
        position: location,
      ));
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permissions are permanently denied.')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _selectedLocation = LatLng(position.latitude, position.longitude);
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_selectedLocation!),
      );
      _markers.clear();
      _markers.add(Marker(
        markerId: MarkerId('selected_location'),
        position: _selectedLocation!,
      ));
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Save all form fields
    _formKey.currentState!.save();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final token = await authProvider.getToken();
      if (token == null) {
        throw Exception('No token found. Please log in.');
      }

      final body = json.encode({
        'name': _name,
        'type': _type,
        'location': _location,
        'latitude': _selectedLocation?.latitude,
        'longitude': _selectedLocation?.longitude,
      });

      final response = await http.post(
        Uri.parse('http://localhost:3002/markets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Market created successfully!')),
        );
        await authProvider.fetchMarkets();
        Navigator.of(context).pop();
      } else {
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
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Market'),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 3) {
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
            Step(
              title: Text('Market Geolocation'),
              content: Column(
                children: [
                  ElevatedButton(
                    onPressed: _getCurrentLocation,
                    child: Text('Use Current Location'),
                  ),
                  SizedBox(height: 16),
                  Container(
                    height: 300,
                    child: GoogleMap(
                      onMapCreated: _onMapCreated,
                      onTap: _onMapTapped,
                      initialCameraPosition: CameraPosition(
                        target: _selectedLocation ?? LatLng(0, 0),
                        zoom: 15,
                      ),
                      markers: _markers,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
