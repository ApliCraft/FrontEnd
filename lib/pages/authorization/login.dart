import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../api/user.dart' as user_api;
import 'register.dart';
import '../home.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:decideat/api/api.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:email_validator/email_validator.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _obscureText = true;
  bool _isLoading = false;
  bool _showSocialLogin = false; // Flag to control social login visibility

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
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

  String? _validatePassword(String? value) {
    final loc = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) {
      return loc.pleaseEnterPassword;
    }
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final loc = AppLocalizations.of(context)!;
    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      // Call the login function from the user_api
      final result = await user_api.login(email, password, context);
      
      // Show appropriate messages based on the result
      if (!result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.loginSuccessful),
            backgroundColor: Colors.green,
          ),
        );
        // Navigation is handled in the login function
      }
    } finally {
      // Make sure to set loading to false
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSocialButton(String assetPath, VoidCallback onPressed) {
    // Check if the asset exists
    try {
      return InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SvgPicture.asset(
            assetPath,
            width: 24,
            height: 24,
            placeholderBuilder: (BuildContext context) =>
                Icon(Icons.account_circle, size: 24, color: Colors.grey),
          ),
        ),
      );
    } catch (e) {
      // Fallback to a generic icon if SVG asset isn't available
      return InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.account_circle, size: 24, color: Colors.grey),
        ),
      );
    }
  }

  Widget _buildSocialLoginSection(AppLocalizations loc) {
    // Return an empty container when social login is disabled
    if (!_showSocialLogin) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[400])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                loc.orContinueWith,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[400])),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialButton('assets/icons/google.svg', () {}),
            const SizedBox(width: 20),
            _buildSocialButton('assets/icons/facebook.svg', () {}),
            const SizedBox(width: 20),
            _buildSocialButton('assets/icons/x.svg', () {}),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo section with centered alignment
                  Center(
                    child: Image.asset(
                      'assets/logo.png',
                      height: 120,
                      width: 120,
                      errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.image_not_supported,
                          size: 80,
                          color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Welcome section
                  Text(
                    "Welcome Back",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Sign in to continue",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 30),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
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
                    onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  ),
                  const SizedBox(height: 16),

                  // Password field
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
                          _obscureText
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: _togglePasswordVisibility,
                      ),
                    ),
                    obscureText: _obscureText,
                    validator: _validatePassword,
                    onFieldSubmitted: (_) => _login(),
                  ),

                  // Forgot password button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Show a snackbar until this feature is implemented
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                "Forgot password feature not implemented yet"),
                            action: SnackBarAction(
                              label: 'OK',
                              onPressed: () {},
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                      child: Text(loc.forgotPassword),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            loc.login,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // "Don't have an account" section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?"),
                      const SizedBox(width: 5),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              transitionDuration:
                                  const Duration(milliseconds: 500),
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const RegisterPage(),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
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
                        child: Text(loc.register),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Social login section (conditionally rendered)
                  _buildSocialLoginSection(loc),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
