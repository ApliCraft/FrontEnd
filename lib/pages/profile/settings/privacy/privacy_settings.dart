import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/widgets/bottomNavBar.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({Key? key}) : super(key: key);

  @override
  _PrivacySettingsPageState createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _locationSharing = false;
  bool _dataCollection = true;
  bool _profileVisibility = true;

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
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, const Color.fromARGB(0, 255, 255, 255)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 80),
            Center(
              child: Text(
                loc.privacySettings,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      loc.locationSharing,
                      loc.locationSharingDescription,
                      Icons.location_on,
                      _locationSharing,
                      (value) {
                        setState(() {
                          _locationSharing = value;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value ? loc.locationSharingEnabled : loc.locationSharingDisabled,
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    _buildSwitchTile(
                      loc.dataCollection,
                      loc.dataCollectionDescription,
                      Icons.data_usage,
                      _dataCollection,
                      (value) {
                        setState(() {
                          _dataCollection = value;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value ? loc.dataCollectionEnabled : loc.dataCollectionDisabled,
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    _buildSwitchTile(
                      loc.profileVisibility,
                      loc.profileVisibilityDescription,
                      Icons.visibility,
                      _profileVisibility,
                      (value) {
                        setState(() {
                          _profileVisibility = value;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value ? loc.profileVisibilityEnabled : loc.profileVisibilityDisabled,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                loc.privacySettingsDisclaimer,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 4),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon,
      bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.green.shade800),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        // onChanged: onChanged,
        onChanged: null, // Disable the switch
        activeColor: Colors.green.shade400,
      ),
    );
  }
}

