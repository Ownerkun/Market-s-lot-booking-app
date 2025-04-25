import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  bool obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _selectedRole;
  String? _userRole;
  DateTime? _birthDate;

  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedSubdistrict;
  List<String> _provinces = [];
  List<String> _districts = [];
  List<String> _subdistricts = [];
  List<dynamic> _provincesData = [];
  List<dynamic> _districtsData = [];
  List<dynamic> _subdistrictsData = [];

  bool get isAdmin => _userRole == 'ADMIN';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    print('Initializing AuthScreen...'); // Debug
    _fetchProvinces();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchProvinces() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://raw.githubusercontent.com/kongvut/thai-province-data/master/api_province.json'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _provincesData = data;
          _provinces = data.map((item) => item['name_en'] as String).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load provinces: $e')),
      );
    }
  }

  Future<void> _fetchDistricts(String province) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://raw.githubusercontent.com/kongvut/thai-province-data/master/api_amphure.json'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final provinceId = _provincesData.firstWhere(
          (item) => item['name_en'] == province,
          orElse: () => null,
        )?['id'];

        if (provinceId != null) {
          setState(() {
            _districtsData = data
                .where((item) => item['province_id'] == provinceId)
                .toList();
            _districts = _districtsData
                .map((item) => item['name_en'] as String)
                .toList();
            _selectedDistrict = null;
            _selectedSubdistrict = null;
            _subdistricts = [];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load districts: $e')),
      );
    }
  }

  Future<void> _fetchSubdistricts(String province, String district) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://raw.githubusercontent.com/kongvut/thai-province-data/master/api_tambon.json'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final districtId = _districtsData.firstWhere(
          (item) => item['name_en'] == district,
          orElse: () => null,
        )?['id'];

        if (districtId != null) {
          setState(() {
            _subdistrictsData =
                data.where((item) => item['amphure_id'] == districtId).toList();
            _subdistricts = _subdistrictsData
                .map((item) => item['name_en'] as String)
                .toList();
            _selectedSubdistrict = null;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load subdistricts: $e')),
      );
    }
  }

  void _toggleAuthMode() {
    setState(() {
      isLogin = !isLogin;
      _animationController.reset();
      _animationController.forward();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // For registration, additional validation for required fields
    if (!isLogin) {
      if (_birthDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Please select your birth date'),
              backgroundColor: Colors.red),
        );
        return;
      }
      if (_selectedProvince == null ||
          _selectedDistrict == null ||
          _selectedSubdistrict == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Please complete your address information'),
              backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (isLogin) {
        await authProvider.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        if (_selectedRole == 'ADMIN') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Admin registration not allowed'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // All fields are validated, proceed with registration
        await authProvider.register(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _selectedRole!,
          _firstNameController.text.trim(),
          _lastNameController.text.trim(),
          _birthDate!, // Safe to use ! as we validated it above
          _selectedProvince!,
          _selectedDistrict!,
          _selectedSubdistrict!,
        );
      }

      if (authProvider.errorMessage == null) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now()
          .subtract(Duration(days: 365 * 18)), // Defaulting to 18 years ago
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
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData? prefixIcon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade700),
      prefixIcon:
          prefixIcon != null ? Icon(prefixIcon, color: Colors.green) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.green, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  List<DropdownMenuItem<String>> _buildRoleDropdownItems(BuildContext context) {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isAdmin = authProvider.isAdmin;

      return [
        DropdownMenuItem(
          value: 'TENANT',
          child: Text('Tenant'),
        ),
        DropdownMenuItem(
          value: 'LANDLORD',
          child: Text('Landlord'),
        ),
        if (isAdmin)
          DropdownMenuItem(
            value: 'ADMIN',
            child: Text('Admin'),
          ),
      ];
    } catch (e) {
      return [
        DropdownMenuItem(
          value: 'TENANT',
          child: Text('Tenant'),
        ),
        DropdownMenuItem(
          value: 'LANDLORD',
          child: Text('Landlord'),
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade100, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo or App Name with icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart,
                              size: 36,
                              color: Colors.green.shade700,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'EasyMarket',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.03),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 30),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Auth mode selector
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          if (!isLogin) _toggleAuthMode();
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isLogin
                                                ? Colors.green
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Sign In',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isLogin
                                                  ? Colors.white
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          if (isLogin) _toggleAuthMode();
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 12),
                                          decoration: BoxDecoration(
                                            color: !isLogin
                                                ? Colors.green
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Sign Up',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: !isLogin
                                                  ? Colors.white
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),

                              // Welcome Text
                              Text(
                                isLogin ? 'Welcome Back!' : 'Create Account',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                              SizedBox(height: 8),
                              Text(
                                isLogin
                                    ? 'Sign in to continue to EasyMarket'
                                    : 'Fill in your details to get started',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: 24),

                              // Form Fields
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration:
                                    _buildInputDecoration('Email', Icons.email),
                                validator: (value) {
                                  if (value!.isEmpty || !value.contains('@')) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: obscurePassword,
                                decoration: _buildInputDecoration(
                                        'Password', Icons.lock)
                                    .copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey.shade600,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        obscurePassword = !obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value!.isEmpty || value.length < 6) {
                                    return 'Password must be at least 6 characters long';
                                  }
                                  return null;
                                },
                              ),

                              // Registration Fields
                              if (!isLogin) ...[
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _firstNameController,
                                        decoration: _buildInputDecoration(
                                            'First Name', Icons.person),
                                        validator: (value) {
                                          if (value!.isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _lastNameController,
                                        decoration: _buildInputDecoration(
                                            'Last Name', null),
                                        validator: (value) {
                                          if (value!.isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedRole,
                                  decoration: _buildInputDecoration(
                                      'Role', Icons.assignment_ind),
                                  items: _buildRoleDropdownItems(context),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRole = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select a role';
                                    }
                                    return null;
                                  },
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: Colors.green),
                                  dropdownColor: Colors.white,
                                ),
                                SizedBox(height: 16),
                                TextFormField(
                                  decoration: _buildInputDecoration(
                                      'Birth Date', Icons.calendar_today),
                                  readOnly: true,
                                  controller: TextEditingController(
                                    text: _birthDate != null
                                        ? DateFormat('MMMM d, yyyy')
                                            .format(_birthDate!)
                                        : '',
                                  ),
                                  onTap: () => _selectBirthDate(context),
                                  validator: (value) {
                                    if (_birthDate == null) {
                                      return 'Please select your birth date';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Address',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedProvince,
                                  decoration: _buildInputDecoration(
                                      'Province', Icons.location_city),
                                  items: _provinces.map((String province) {
                                    return DropdownMenuItem<String>(
                                      value: province,
                                      child: Text(province),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    print(
                                        'Province selected: $newValue'); // Debug
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedProvince = newValue;
                                        _selectedDistrict = null;
                                        _selectedSubdistrict = null;
                                        _subdistricts = [];
                                      });
                                      _fetchDistricts(newValue);
                                    }
                                  },
                                  validator: (value) => value == null
                                      ? 'Please select a province'
                                      : null,
                                  isExpanded: true,
                                ),
                                SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedDistrict,
                                  decoration: _buildInputDecoration(
                                      'District', Icons.location_on),
                                  items: _districts.map((String district) {
                                    return DropdownMenuItem<String>(
                                      value: district,
                                      child: Text(district),
                                    );
                                  }).toList(),
                                  onChanged: _selectedProvince == null
                                      ? null
                                      : (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              _selectedDistrict = newValue;
                                              _selectedSubdistrict = null;
                                            });
                                            _fetchSubdistricts(
                                                _selectedProvince!, newValue);
                                          }
                                        },
                                  validator: (value) => value == null
                                      ? 'Please select a district'
                                      : null,
                                  isExpanded: true,
                                ),
                                SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedSubdistrict,
                                  decoration: _buildInputDecoration(
                                      'Subdistrict', Icons.map),
                                  items:
                                      _subdistricts.map((String subdistrict) {
                                    return DropdownMenuItem<String>(
                                      value: subdistrict,
                                      child: Text(subdistrict),
                                    );
                                  }).toList(),
                                  onChanged: _selectedDistrict == null
                                      ? null
                                      : (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              _selectedSubdistrict = newValue;
                                            });
                                          }
                                        },
                                  validator: (value) => value == null
                                      ? 'Please select a subdistrict'
                                      : null,
                                  isExpanded: true,
                                ),
                              ],

                              // Forgot Password (only for login)
                              if (isLogin) ...[
                                SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {},
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size(50, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              SizedBox(height: 24),

                              // Submit Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          isLogin
                                              ? 'Sign In'
                                              : 'Create Account',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),

                              // Or divider
                              SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                        color: Colors.grey.shade300,
                                        thickness: 1),
                                  ),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'Or continue with',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                        color: Colors.grey.shade300,
                                        thickness: 1),
                                  ),
                                ],
                              ),

                              // Social Login Buttons
                              SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _socialLoginButton(
                                    icon: Icons.g_mobiledata,
                                    backgroundColor: Colors.white,
                                    onPressed: () {},
                                  ),
                                  SizedBox(width: 16),
                                  _socialLoginButton(
                                    icon: Icons.apple,
                                    backgroundColor: Colors.white,
                                    onPressed: () {},
                                  ),
                                ],
                              ),

                              // Sign up/Sign in link
                              SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isLogin
                                        ? "Don't have an account? "
                                        : "Already have an account? ",
                                    style:
                                        TextStyle(color: Colors.grey.shade600),
                                  ),
                                  GestureDetector(
                                    onTap: _toggleAuthMode,
                                    child: Text(
                                      isLogin ? 'Sign Up' : 'Sign In',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialLoginButton({
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        height: 56,
        width: 56,
        child: Icon(icon, size: 30, color: Colors.black87),
      ),
    );
  }
}
