import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/auth_provider.dart';
import 'package:intl/intl.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _selectedRole;
  DateTime? _birthDate;

  void _toggleAuthMode() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (isLogin) {
      await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } else {
      await authProvider.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _selectedRole!,
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
        _birthDate,
      );
    }

    if (authProvider.errorMessage == null) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'EasyMarket',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _toggleAuthMode,
                              child: Text(
                                'Create Account',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isLogin ? Colors.grey : Colors.black,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _toggleAuthMode,
                              child: Text(
                                'Log In',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isLogin ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          isLogin ? 'Welcome Back' : 'Create Account',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 5),
                        Text('Fill out the form below.'),
                        SizedBox(height: 10),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  20), // Match button roundness
                            ),
                          ),
                          validator: (value) {
                            if (value!.isEmpty || !value.contains('@')) {
                              return 'Please enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 10),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  20), // Match button roundness
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
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
                              return 'Password must be at least 6 characters long.';
                            }
                            return null;
                          },
                        ),
                        if (!isLogin) ...[
                          SizedBox(height: 10),
                          TextFormField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: 'First Name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    20), // Match button roundness
                              ),
                            ),
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Please enter your first name.';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 10),
                          TextFormField(
                            controller: _lastNameController,
                            decoration: InputDecoration(
                              labelText: 'Last Name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    20), // Match button roundness
                              ),
                            ),
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Please enter your last name.';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    20), // Match button roundness
                              ),
                            ),
                            items: ['TENANT', 'LANDLORD'].map((String role) {
                              return DropdownMenuItem<String>(
                                value: role,
                                child: Text(role),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a role.';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 10),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Birth Date',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    20), // Match button roundness
                              ),
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text: _birthDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_birthDate!)
                                  : '',
                            ),
                            onTap: () => _selectBirthDate(context),
                            validator: (value) {
                              if (_birthDate == null) {
                                return 'Please select your birth date.';
                              }
                              return null;
                            },
                          ),
                        ],
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 50),
                          ),
                          child: Text(isLogin ? 'Sign In' : 'Get Started'),
                        ),
                        SizedBox(height: 10),
                        Text('Or sign up with'),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.g_mobiledata, size: 32),
                              onPressed: () {},
                            ),
                            SizedBox(width: 20),
                            IconButton(
                              icon: Icon(Icons.apple, size: 32),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        if (isLogin)
                          TextButton(
                            onPressed: () {},
                            child: Text('Forgot Password?'),
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
    );
  }
}

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AuthScreen(),
  ));
}
