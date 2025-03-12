import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:decideat/api/api.dart';
import 'package:country_picker/country_picker.dart';
import 'package:decideat/api/user.dart' as user_api;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  
  // Controllers for required fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatedPasswordController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  
  // Controllers for optional fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  
  // Store selected country
  Country? _selectedCountry;
  
  // Focus nodes
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _repeatedPasswordFocusNode = FocusNode();

  bool _obscureText = true;
  int _currentPage = 0;
  final int _totalPages = 5;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      setState(() {});
    });
    
    _pageController.addListener(() {
      int page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() {
          _currentPage = page;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _repeatedPasswordController.dispose();
    _dateOfBirthController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _countryController.dispose();
    _phoneNumberController.dispose();
    _passwordFocusNode.dispose();
    _repeatedPasswordFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  String? _validateEmail(String? value) {
    final loc = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) {
      return loc.pleaseEnterEmail;
    }
    if (!EmailValidator.validate(value)) {
      return loc.pleaseEnterValidEmail;
    }
    return null;
  }

  String? _validateUsername(String? value) {
    final loc = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) {
      return loc.pleaseEnterUsername;
    }
    if (value.length < 3) {
      return loc.usernameTooShort;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final loc = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) {
      return loc.pleaseEnterPassword;
    }
    final passwordRegex =
        RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9]).{8,}$');
    if (!passwordRegex.hasMatch(value)) {
      return loc.passwordRequirements;
    }
    return null;
  }

  String? _validateDateOfBirth(String? value) {
    final loc = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) {
      return loc.pleaseEnterDateOfBirth;
    }
    
    try {
      final date = DateFormat('yyyy-MM-dd').parse(value);
      final now = DateTime.now();
      final difference = now.difference(date);
      final age = difference.inDays ~/ 365;
      
      if (age < 13) {
        return 'You must be at least 13 years old to register.';
      }
      
      return null;
    } catch (e) {
      return 'Please enter a valid date in format YYYY-MM-DD';
    }
  }

  void _nextPage() {
    // Validate the current page before moving to the next
    if (_validateCurrentPage()) {
      if (_currentPage < _totalPages - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _submitForm();
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0: // Email page
        return _validateEmail(_emailController.text) == null;
      case 1: // Username page
        return _validateUsername(_usernameController.text) == null;
      case 2: // Password page
        return _validatePassword(_passwordController.text) == null && 
               _passwordController.text == _repeatedPasswordController.text;
      case 3: // Date of birth page
        return _validateDateOfBirth(_dateOfBirthController.text) == null;
      case 4: // Optional info page
        return true; // Optional info doesn't need validation
      default:
        return false;
    }
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      _register();
    }
  }

  Future<void> _register() async {
    final loc = AppLocalizations.of(context)!;
    final registerUrl = Uri.parse('$apiUrl/user');
    
    // Prepare user data with all fields
    final userData = {
      'email': _emailController.text,
      'username': _usernameController.text,
      'password': _passwordController.text,
      'dateOfBirth': _dateOfBirthController.text,
    };
    
    // Add optional fields if they are not empty
    if (_firstNameController.text.isNotEmpty) {
      userData['firstName'] = _firstNameController.text;
    }
    if (_lastNameController.text.isNotEmpty) {
      userData['lastName'] = _lastNameController.text;
    }
    if (_selectedCountry != null) {
      userData['country'] = _selectedCountry!.name;
    }
    if (_phoneNumberController.text.isNotEmpty) {
      userData['phoneNumber'] = _phoneNumberController.text;
    }

    try {
      // print(userData);
      // print(registerUrl);
      // print(jsonEncode(userData));
      final response = await http.post(
        registerUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.registrationSuccessful),
            backgroundColor: Colors.green,
          ),
        );
        // After successful registration, attempt to login
        final loginResult = await user_api.login(_emailController.text, _passwordController.text, context);
        
        if (!loginResult['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loginResult['message']),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginPage(),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.registrationFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 14)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _selectCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country;
          _countryController.text = country.name;
        });
      },
      countryListTheme: CountryListThemeData(
        borderRadius: BorderRadius.circular(12),
        inputDecoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.country,
          hintText: 'Search for country',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalPages, (index) {
          return Container(
            width: 10.0,
            height: 10.0,
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentPage == index
                  ? Theme.of(context).primaryColor
                  : Colors.grey.withOpacity(0.5),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmailPage() {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "What's your email address?",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              "We'll use this to create your account.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: loc.email,
                hintText: 'example@email.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
              onFieldSubmitted: (_) => _nextPage(),
            ),
            if (_validateEmail(_emailController.text) != null && _emailController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                child: Text(
                  _validateEmail(_emailController.text)!,
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernamePage() {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Choose a username",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              "Your username should be at least 3 characters long.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: loc.username,
                hintText: 'YourUsername',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              textInputAction: TextInputAction.next,
              validator: _validateUsername,
              onFieldSubmitted: (_) => _nextPage(),
            ),
            if (_validateUsername(_usernameController.text) != null && _usernameController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                child: Text(
                  _validateUsername(_usernameController.text)!,
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordPage() {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Create a secure password",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              "Your password should have at least 8 characters, including uppercase, lowercase, and numbers.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              decoration: InputDecoration(
                labelText: loc.password,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: _togglePasswordVisibility,
                ),
              ),
              obscureText: _obscureText,
              validator: _validatePassword,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _repeatedPasswordController,
              focusNode: _repeatedPasswordFocusNode,
              decoration: InputDecoration(
                labelText: loc.repeatedPassword,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: _togglePasswordVisibility,
                ),
              ),
              obscureText: _obscureText,
              validator: (value) {
                if (value != _passwordController.text) {
                  return loc.passwordsDoNotMatch;
                }
                return null;
              },
              onFieldSubmitted: (_) => _nextPage(),
            ),
            if (_passwordController.text.isNotEmpty && 
                _validatePassword(_passwordController.text) != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                child: Text(
                  _validatePassword(_passwordController.text)!,
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ),
            if (_repeatedPasswordController.text.isNotEmpty && 
                _passwordController.text != _repeatedPasswordController.text)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                child: Text(
                  loc.passwordsDoNotMatch,
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateOfBirthPage() {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "When were you born?",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              "You must be at least 13 years old to register.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _dateOfBirthController,
              decoration: InputDecoration(
                labelText: loc.dateOfBirth,
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.calendar_today),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: _selectDate,
                ),
              ),
              readOnly: true,
              onTap: _selectDate,
              validator: _validateDateOfBirth,
            ),
            if (_dateOfBirthController.text.isNotEmpty && 
                _validateDateOfBirth(_dateOfBirthController.text) != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                child: Text(
                  _validateDateOfBirth(_dateOfBirthController.text)!,
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionalInfoPage() {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tell us more about yourself (Optional)",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              "These details help us personalize your experience.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: loc.firstName,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: loc.lastName,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            // Country picker field
            TextFormField(
              controller: _countryController,
              decoration: InputDecoration(
                labelText: loc.country,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.public),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              readOnly: true,
              onTap: _selectCountry,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneNumberController,
              decoration: InputDecoration(
                labelText: loc.phoneNumber,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            // Add extra space at bottom to ensure all content is visible when keyboard appears
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    // Get the available screen size
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = screenHeight - keyboardHeight;
    
    return Scaffold(
      // Use resizeToAvoidBottomInset to handle keyboard appearance
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        // Wrap everything in a CustomScrollView to handle overall scrolling if needed
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildPageIndicator(),
              // Make the PageView expandable but with proper constraints
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Disable swiping
                  children: [
                    _buildEmailPage(),
                    _buildUsernamePage(),
                    _buildPasswordPage(),
                    _buildDateOfBirthPage(),
                    _buildOptionalInfoPage(),
                  ],
                ),
              ),
              // Keep navigation buttons at the bottom
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _currentPage > 0
                            ? TextButton.icon(
                                onPressed: _previousPage,
                                icon: const Icon(Icons.arrow_back),
                                label: Text('Back'),
                              )
                            : const SizedBox(width: 100),
                        ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(_currentPage == _totalPages - 1 ? loc.register : 'Next'),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(loc.alreadyHaveAccount),
                          const SizedBox(width: 5),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                PageRouteBuilder(
                                  transitionDuration: const Duration(milliseconds: 500),
                                  pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(
                                      opacity: animation.drive(
                                        CurveTween(curve: Curves.easeInOut),
                                      ),
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).primaryColor,
                            ),
                            child: Text(loc.signIn),
                          ),
                        ],
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
}
