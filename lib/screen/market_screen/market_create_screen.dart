import 'package:flutter/material.dart';
import 'package:market_lot_app/provider/market_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MarketCreationWizard extends StatefulWidget {
  @override
  _MarketCreationWizardState createState() => _MarketCreationWizardState();
}

class _MarketCreationWizardState extends State<MarketCreationWizard> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form controllers
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  LatLng? _selectedLocation;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  List<Map<String, dynamic>> _availableTags = [];
  List<String> _selectedTagIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTags();
    });
  }

  Future<void> _loadTags() async {
    try {
      setState(() => _isLoading = true);
      final marketProvider =
          Provider.of<MarketProvider>(context, listen: false);
      final tags = await marketProvider.fetchMarketTags();

      if (mounted) {
        setState(() {
          _availableTags = tags
              .map((tag) => {'id': tag['id'], 'name': tag['name']})
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load tags: $e');
      }
    }
  }

  // Input decoration
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.green),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.green, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

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
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('Location permissions are permanently denied.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _markers.clear();
        _markers.add(Marker(
          markerId: MarkerId('selected_location'),
          position: _selectedLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ));
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _selectedLocation!,
            zoom: 15,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final marketProvider = Provider.of<MarketProvider>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      await marketProvider.createMarket(
        name: _nameController.text,
        location: _locationController.text,
        position: _selectedLocation!,
        tagIds: _selectedTagIds,
        context: context,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to create market: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Market Name
        return _nameController.text.trim().isNotEmpty &&
            _nameController.text.trim().length >= 3;
      case 1: // Market Tags
        return _selectedTagIds.isNotEmpty;
      case 2: // Location Details
        return _locationController.text.trim().isNotEmpty;
      case 3: // Map Location
        return _selectedLocation != null;
      default:
        return false;
    }
  }

  void _handleStepContinue() {
    if (_isLoading) return;

    final isCurrentStepValid = _validateCurrentStep();
    print(
        'Step $_currentStep validation result: $isCurrentStepValid'); // Debug log

    if (isCurrentStepValid) {
      if (_currentStep < 3) {
        setState(() {
          _currentStep++;
        });
      } else {
        _submit();
      }
    } else {
      String errorMessage;
      switch (_currentStep) {
        case 0:
          errorMessage = 'Please enter a valid market name';
          break;
        case 1:
          errorMessage = 'Please select at least one tag';
          break;
        case 2:
          errorMessage = 'Please enter a valid location';
          break;
        case 3:
          errorMessage = 'Please select a location on the map';
          break;
        default:
          errorMessage = 'Please complete all required fields';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.all(10),
        ),
      );
    }
  }

  void _handleStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _showAddTagDialog(BuildContext context) async {
    final tagController = TextEditingController();
    final marketProvider = Provider.of<MarketProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create New Tag'),
          content: TextField(
            controller: tagController,
            decoration: InputDecoration(
              labelText: 'Tag Name',
              hintText: 'e.g. Food, Clothing, Electronics',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tagController.text.trim().isNotEmpty) {
                  try {
                    await marketProvider.createTag(tagController.text.trim());
                    final updatedTags = await marketProvider.fetchMarketTags();
                    setState(() {
                      _availableTags = updatedTags;
                      _selectedTagIds.add(tagController.text.trim());
                    });
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create tag: $e')),
                    );
                  }
                }
              },
              child: Text('Create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Market'),
        elevation: 0,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.white],
          ),
        ),
        child: Form(
          key: _formKey,
          child: Stepper(
            currentStep: _currentStep,
            elevation: 0,
            type: StepperType.horizontal,
            onStepContinue: _handleStepContinue,
            onStepCancel: _handleStepCancel,
            controlsBuilder: (context, details) {
              return Padding(
                padding: EdgeInsets.only(top: 20),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleStepCancel,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.green),
                          ),
                          child: Text('Back'),
                        ),
                      ),
                    if (_currentStep > 0) SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor:
                              Colors.white, // This will make the text white
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                _currentStep == 3 ? 'Create Market' : 'Next',
                                style: TextStyle(
                                    color: Colors
                                        .white), // This ensures text is white
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
            steps: [
              _buildStep(
                'Market Name',
                Icons.store,
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration('Market Name', Icons.store),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Market name is required';
                    }
                    if (value.trim().length < 3) {
                      return 'Market name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
              ),
              _buildStep(
                'Market Tags',
                Icons.label,
                Column(
                  children: [
                    if (_availableTags.isEmpty)
                      Column(
                        children: [
                          Text(
                            'No tags available',
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _showAddTagDialog(context),
                            child: Text('Create New Tag'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableTags.map((tag) {
                              return FilterChip(
                                label: Text(tag['name']),
                                selected: _selectedTagIds.contains(tag['id']),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedTagIds.add(tag['id']);
                                    } else {
                                      _selectedTagIds.remove(tag['id']);
                                    }
                                  });
                                },
                                selectedColor: Colors.green.shade100,
                                checkmarkColor: Colors.green,
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _showAddTagDialog(context),
                            child: Text('Add New Tag'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    if (_selectedTagIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          'Selected tags: ${_selectedTagIds.join(', ')}',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                  ],
                ),
              ),
              _buildStep(
                'Location Details',
                Icons.location_on,
                TextFormField(
                  controller: _locationController,
                  decoration:
                      _buildInputDecoration('Address', Icons.location_on),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Address is required';
                    }
                    return null;
                  },
                ),
              ),
              _buildStep(
                'Map Location',
                Icons.map,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: Icon(Icons.my_location),
                      label: Text('Use Current Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    if (_selectedLocation == null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Please select a location on the map',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedLocation == null
                              ? Colors.red.shade200
                              : Colors.grey.shade300,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GoogleMap(
                        onMapCreated: _onMapCreated,
                        onTap: _onMapTapped,
                        initialCameraPosition: CameraPosition(
                          target: _selectedLocation ??
                              LatLng(13.7563, 100.5018), // Bangkok coordinates
                          zoom: 15,
                        ),
                        markers: _markers,
                        mapType: MapType.normal,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Step _buildStep(String title, IconData icon, Widget content) {
    List<Step> allSteps = [
      Step(title: Text('Market Name'), content: Container()),
      Step(title: Text('Market Type'), content: Container()),
      Step(title: Text('Location Details'), content: Container()),
      Step(title: Text('Map Location'), content: Container()),
    ];

    return Step(
      title: Text(title),
      isActive: _currentStep >=
          allSteps.indexWhere(
              (step) => step.title.toString() == Text(title).toString()),
      content: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: content,
        ),
      ),
    );
  }
}
