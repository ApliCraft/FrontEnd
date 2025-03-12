import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:decideat/api/api.dart';
import 'package:decideat/widgets/navigationProfileAppBar.dart';
import 'package:decideat/widgets/bottomNavBar.dart';
import 'package:decideat/widgets/loading_widget.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:email_validator/email_validator.dart';

class EmailPage extends StatefulWidget {
  const EmailPage({Key? key}) : super(key: key);

  @override
  _EmailPageState createState() => _EmailPageState();
}

class _EmailPageState extends State<EmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _newEmailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  String currentEmail = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    _confirmEmailController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserInfo() async {
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
          currentEmail = data['email'] ?? '';
          _isLoading = false;
        });
      } else {
        print('Failed to load user information: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
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
            'email': _newEmailController.text.trim(),
          }),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.emailUpdatedSuccess),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.emailUpdateFailed} (${response.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
                      loc.changeEmail,
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
                            // Current Email Display
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.email_outlined, color: Colors.green),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          loc.currentEmail,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          currentEmail,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _newEmailController,
                              decoration: InputDecoration(
                                labelText: loc.newEmail,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return loc.pleaseEnterEmail;
                                }
                                if (!EmailValidator.validate(value)) {
                                  return loc.pleaseEnterValidEmail;
                                }
                                if (value.trim() == currentEmail) {
                                  return 'New email must be different from current email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmEmailController,
                              decoration: InputDecoration(
                                labelText: loc.confirmNewEmail,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return loc.pleaseEnterEmail;
                                }
                                if (value != _newEmailController.text) {
                                  return loc.emailsDoNotMatch;
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