import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:decideat/api/api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:decideat/pages/profile.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  String username = '';
  String description = '';

  // State variable for avatar URL.
  String _avatarUrl = '$apiUrl/images/default_avatar.png';

  bool _isLoading = true; // Loading flag

  @override
  void initState() {
    super.initState();
    RefreshTokenIfExpired();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    final userUrl = Uri.parse('$apiUrl/user/user-info');
    String? token = await storage.read(key: "accessToken");
    if (token != null) {
      final response = await http.get(userUrl, headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      });
      if (response.statusCode == 200) {
        setState(() {
          final data = jsonDecode(response.body);
          username = data['username'];
          description = data['description'];
          _avatarUrl =
              '$apiUrl/images/${(data['avatarLink'].split('/').last) == '' ? "default_avatar.png" : data['avatarLink'].split('/').last}';
          _isLoading = false;
        });
      } else {
        print('Failed to load user info');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 800;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      // Back button using FloatingActionButton at top left corner
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: FloatingActionButton(
          onPressed: () {
            // Replace current route with a fresh profile page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
        (Route<dynamic> route) => false, // Remove all previous routes
      );
          },
          child: const Icon(Icons.arrow_back),
          backgroundColor: Colors.green.shade200,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
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
              child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: isLargeScreen
                      ? Center(
                          child: Column(
                          children: [
                            const SizedBox(height: 16),
                            Text(
                              loc.editProfile,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: _buildForm(context, loc),
                            ),
                          ],
                        ))
                      : Center(
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              Text(
                                loc.editProfile,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildForm(context, loc),
                            ],
                          ),
                        ),
                ),
              )),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations loc) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar Section with options to change or delete image
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: NetworkImage(_avatarUrl),
                ),
                // Edit Button
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: Colors.blue,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final pickedFile =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          final bytes = await pickedFile.readAsBytes();
                          final base64String = base64Encode(bytes);
                          String? accessToken =
                              await storage.read(key: 'accessToken');

                          final url = Uri.parse('$apiUrl/user/set-avatar');
                          final response = await http.put(
                            url,
                            headers: <String, String>{
                              'Content-Type': 'application/json; charset=UTF-8',
                              'Authorization': 'Bearer $accessToken',
                            },
                            body: jsonEncode(<String, String>{
                              'base64Image':
                                  'data:image/png;base64,$base64String',
                            }),
                          );

                          if (response.statusCode == 200) {
                            String filePath = response.body.replaceAll('"', '');
                            String fileName = filePath.split('/').last;
                            setState(() {
                              _avatarUrl = '$apiUrl/images/$fileName';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text("Avatar successfully changed!")),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      "Failed to upload image / change avatar")),
                            );
                            print(response.body);
                            print(response.statusCode);
                            print(response.toString());
                          }
                        }
                      },
                    ),
                  ),
                ),
                // Delete Button: resets avatar to default
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () async {
                        try {
                          await RefreshTokenIfExpired();
                          String? token =
                              await storage.read(key: 'accessToken');
                          if (token != null) {
                            final url =
                                Uri.parse('$apiUrl/user/update-user-profile');
                            final response = await http.put(
                              url,
                              headers: {
                                'Content-Type': 'application/json',
                                'Authorization': 'Bearer $token',
                              },
                              body: jsonEncode({
                                'avatarLink': 'uploads/images/default_avatar.png',
                              }),
                            );

                            if (response.statusCode == 200) {
                              setState(() {
                                _avatarUrl =
                                    '$apiUrl/images/default_avatar.png';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Avatar successfully reset to default'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Failed to reset avatar (${response.statusCode})'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Session expired. Please login again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error resetting avatar: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error resetting avatar: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Username Field
          TextFormField(
            initialValue: username,
            decoration: InputDecoration(
              labelText: "Username",
              border: const OutlineInputBorder(),
            ),
            onSaved: (value) => username = value ?? '',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please enter your username";
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Description Field (multi-line)
          TextFormField(
            initialValue: description,
            decoration: InputDecoration(
              labelText: "Description",
              border: const OutlineInputBorder(),
            ),
            maxLines: 6,
            onSaved: (value) => description = value ?? '',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please enter a description";
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          // Save Button
          ElevatedButton(
            onPressed: () => _submit(loc),
            child: Text("Save Changes"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(AppLocalizations loc) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      await storage
          .read(key: 'accessToken')
          .then((accessToken) async => await _updateProfile(accessToken!));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Profile updated successfully!")),
      );

      // Navigate to profile page and remove all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
        (Route<dynamic> route) => false, // Remove all previous routes
      );
    }
  }

  Future<void> _updateProfile(String accessToken) async {
    final url = Uri.parse('$apiUrl/user/update-user-profile');
    final response = await http.put(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, String>{
        'username': username,
        'description': description,
      }),
    );

    if (response.statusCode == 200) {
      print('Profile updated successfully');
    } else {
      print('Failed to update profile');
      print(response.body);
      print(response.statusCode);
      print(response.toString());
    }
  }
}
