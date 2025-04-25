import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:market_lot_app/provider/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _provinceController = TextEditingController();
  final _districtController = TextEditingController();
  final _subdistrictController = TextEditingController();
  final _postalCodeController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _firstNameController.text = authProvider.userProfile?['firstName'] ?? '';
    _lastNameController.text = authProvider.userProfile?['lastName'] ?? '';
    _provinceController.text = authProvider.userProfile?['province'] ?? '';
    _districtController.text = authProvider.userProfile?['district'] ?? '';
    _subdistrictController.text =
        authProvider.userProfile?['subdistrict'] ?? '';
    _postalCodeController.text = authProvider.userProfile?['postalCode'] ?? '';

    String? birthDateString = authProvider.userProfile?['birthDate'];
    if (birthDateString != null && birthDateString.isNotEmpty) {
      _selectedDate = DateTime.tryParse(birthDateString);
      if (_selectedDate != null) {
        _birthDateController.text =
            DateFormat('MMMM d, yyyy').format(_selectedDate!);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ?? DateTime.now().subtract(Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _birthDateController.text =
            DateFormat('MMMM d, yyyy').format(pickedDate);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a valid birth date')),
        );
        return;
      }

      try {
        await authProvider.updateProfile(
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          birthDate: _selectedDate,
          province: _provinceController.text,
          district: _districtController.text,
          subdistrict: _subdistrictController.text,
          postalCode: _postalCodeController.text,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData? prefixIcon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade700),
      prefixIcon:
          prefixIcon != null ? Icon(prefixIcon, color: Colors.green) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.green, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: Text(
              'Save',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Picture
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(
                        Provider.of<AuthProvider>(context)
                                .userProfile?['profileImage'] ??
                            'https://via.placeholder.com/150',
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),

              // Form Fields
              TextFormField(
                controller: _firstNameController,
                decoration: _buildInputDecoration('First Name', Icons.person),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your first name' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: _buildInputDecoration('Last Name', null),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your last name' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _birthDateController,
                decoration:
                    _buildInputDecoration('Birth Date', Icons.calendar_today),
                readOnly: true,
                onTap: _selectDate,
                validator: (value) =>
                    value!.isEmpty ? 'Please select your birth date' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _provinceController,
                decoration: _buildInputDecoration('Province', null),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your province' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _districtController,
                decoration: _buildInputDecoration('District', null),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your district' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _subdistrictController,
                decoration: _buildInputDecoration('Subdistrict', null),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your subdistrict' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _postalCodeController,
                decoration: _buildInputDecoration('Postal Code', null),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your postal code' : null,
              ),
              SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
