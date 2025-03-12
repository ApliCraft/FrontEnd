import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:decideat/api/api.dart';
import 'package:decideat/widgets/navigationProfileAppBar.dart';
import 'package:decideat/widgets/bottomNavBar.dart';
import 'package:decideat/widgets/loading_widget.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({Key? key}) : super(key: key);

  @override
  _PasswordPageState createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String userEmail = '';
  bool _isLoading = true;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserInfo() async {
    try {
      await RefreshTokenIfExpired();
      final url = Uri.parse('$apiUrl/user/user-info');
      String? token = await storage.read(key: "accessToken");
      if (token != null) {
        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            userEmail = data['email'] ?? '';
            _isLoading = false;
          });
        } else {
          print('Failed to load user information: ${response.statusCode}');
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching user info: $e');
      setState(() => _isLoading = false);
    }
  }

  bool _isPasswordValid(String password) {
    // Password must be at least 8 characters long
    return password.length >= 8;
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
      try {
        await RefreshTokenIfExpired();
        String? token = await storage.read(key: 'accessToken');
        if (token != null) {
          final url = Uri.parse('$apiUrl/user/update-user-profile');
          
          final response = await http.put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'password': _newPasswordController.text,
              'currentPassword': _currentPasswordController.text,
            }),
          );

          print('Server response: ${response.body}'); // Debug log

          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loc.passwordUpdateSuccessful),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${loc.passwordUpdateFailed} (${response.statusCode})'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Session expired. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
          // Handle session expiration (e.g., navigate to login)
        }
      } catch (e) {
        print('Error updating password: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Icon(Icons.arrow_back),
          backgroundColor: Colors.green.shade200,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade50,
              const Color.fromARGB(0, 255, 255, 255)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? loading()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text(
                      loc.updatePassword,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Current Password
                            TextFormField(
                              controller: _currentPasswordController,
                              decoration: InputDecoration(
                                labelText: loc.currentPassword,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureCurrentPassword ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureCurrentPassword = !_obscureCurrentPassword;
                                    });
                                  },
                                ),
                              ),
                              obscureText: _obscureCurrentPassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return loc.pleaseEnterCurrentPassword;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // New Password
                            TextFormField(
                              controller: _newPasswordController,
                              decoration: InputDecoration(
                                labelText: loc.newPassword,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureNewPassword = !_obscureNewPassword;
                                    });
                                  },
                                ),
                              ),
                              obscureText: _obscureNewPassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return loc.pleaseEnterNewPassword;
                                }
                                if (!_isPasswordValid(value)) {
                                  return 'Password must be at least 8 characters long';
                                }
                                if (value == _currentPasswordController.text) {
                                  return 'New password must be different from current password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Confirm New Password
                            TextFormField(
                              controller: _confirmPasswordController,
                              decoration: InputDecoration(
                                labelText: loc.confirmNewPassword,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                              ),
                              obscureText: _obscureConfirmPassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return loc.pleaseConfirmNewPassword;
                                }
                                if (value != _newPasswordController.text) {
                                  return loc.passwordsDoNotMatch;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: FilledButton(
                                onPressed: _submit,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(200, 50),
                                  backgroundColor: Colors.green.shade200,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  loc.save,
                                  style: const TextStyle(fontSize: 16),
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
      ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 4),
    );
  }
}