import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:decideat/api/api.dart';
// import 'package:decideat/api/storage.dart';
import 'package:decideat/widgets/navigationProfileAppBar.dart';
import 'package:decideat/widgets/bottomNavBar.dart';
import 'package:decideat/widgets/loading_widget.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:country_picker/country_picker.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class ProfileInformationPage extends StatefulWidget {
  const ProfileInformationPage({Key? key}) : super(key: key);

  @override
  _ProfileInformationPageState createState() => _ProfileInformationPageState();
}

class _ProfileInformationPageState extends State<ProfileInformationPage> {
  final _formKey = GlobalKey<FormState>();

  String firstName = '';
  String lastName = '';
  String dateOfBirth = '';
  String country = '';
  String phoneNumber = '';
  PhoneNumber initialPhoneNumber = PhoneNumber(isoCode: 'PL');
  DateTime? selectedDate;

  bool _isLoading = true;

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
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
        print('Received data from server: $data'); // Debug log
        setState(() {
          firstName = data['firstName'] ?? '';
          lastName = data['lastName'] ?? '';
          try {
            final dateStr = data['dateOfBirth'] ?? data['DateOfBirth']; // Try both date field names
            if (dateStr != null && dateStr.toString().isNotEmpty) {
              selectedDate = DateTime.parse(dateStr.toString());
              dateOfBirth = _formatDate(selectedDate!);
              print('Parsed date: $dateOfBirth'); // Debug log
            }
          } catch (e) {
            print('Error parsing date: $e');
            dateOfBirth = '';
            selectedDate = null;
          }
          country = data['country'] ?? '';
          phoneNumber = data['phoneNumber'] ?? '';
          if (phoneNumber.isNotEmpty) {
            initialPhoneNumber = PhoneNumber(phoneNumber: phoneNumber);
          }
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
      _formKey.currentState!.save();
      String? token = await storage.read(key: 'accessToken');
      if (token != null) {
        final url = Uri.parse('$apiUrl/user/update-user-profile');
        
        // Ensure date is in the correct format
        final formattedDate = selectedDate != null ? _formatDate(selectedDate!) : null;
        print('Sending date to server: $formattedDate'); // Debug log
        
        final response = await http.put(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'firstName': firstName.isEmpty ? null : firstName,
            'lastName': lastName.isEmpty ? null : lastName,
            'phoneNumber': phoneNumber.isEmpty ? null : phoneNumber,
            'country': country.isEmpty ? null : country,
            'dateOfBirth': formattedDate, // Changed from 'DateOfBirth' to 'dateOfBirth'
          }),
        );

        print('Server response: ${response.body}'); // Debug log

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.profileInfoUpdatedSuccess),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.profileInfoUpdateFailed} (${response.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  bool _isAtLeast13YearsOld(DateTime date) {
    final today = DateTime.now();
    var age = today.year - date.year;
    if (today.month < date.month || 
        (today.month == date.month && today.day < date.day)) {
      age--;
    }
    return age >= 13;
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
                      loc.profileInformation,
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
                          children: [
                            TextFormField(
                              initialValue: firstName,
                              decoration: InputDecoration(
                                labelText: loc.firstName,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                              onSaved: (value) => firstName = value ?? '',
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: lastName,
                              decoration: InputDecoration(
                                labelText: loc.lastName,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                              onSaved: (value) => lastName = value ?? '',
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: TextEditingController(
                                text: selectedDate != null ? _formatDate(selectedDate!) : '',
                              ),
                              decoration: InputDecoration(
                                labelText: '${loc.dateOfBirth} *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.calendar_today),
                                hintText: 'YYYY-MM-DD',
                              ),
                              readOnly: true,
                              onTap: () async {
                                final now = DateTime.now();
                                final initialDate = selectedDate ?? 
                                    now.subtract(const Duration(days: 365 * 13));
                                
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: initialDate,
                                  firstDate: DateTime(1900),
                                  lastDate: now,
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: Colors.green.shade300,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                
                                if (date != null) {
                                  setState(() {
                                    selectedDate = date;
                                    dateOfBirth = _formatDate(date);
                                  });
                                }
                              },
                              validator: (value) {
                                if (selectedDate == null) {
                                  return loc.pleaseEnterDateOfBirth;
                                }
                                if (!_isAtLeast13YearsOld(selectedDate!)) {
                                  return 'You must be at least 13 years old';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () {
                                showCountryPicker(
                                  context: context,
                                  showPhoneCode: false,
                                  onSelect: (Country selectedCountry) {
                                    setState(() {
                                      country = selectedCountry.name;
                                    });
                                  },
                                );
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: loc.country,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.public),
                                ),
                                child: Text(country.isEmpty ? 'Select Country' : country),
                              ),
                            ),
                            const SizedBox(height: 16),
                            InternationalPhoneNumberInput(
                              onInputChanged: (PhoneNumber number) {
                                phoneNumber = number.phoneNumber ?? '';
                              },
                              selectorConfig: const SelectorConfig(
                                selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                              ),
                              initialValue: initialPhoneNumber,
                              inputDecoration: InputDecoration(
                                labelText: loc.phoneNumber,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: null,
                              ignoreBlank: true,
                              autoValidateMode: AutovalidateMode.disabled,
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
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