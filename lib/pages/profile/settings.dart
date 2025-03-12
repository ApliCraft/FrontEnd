import 'package:flutter/material.dart';
// import 'package:flutter/cupertino.dart';
import 'package:decideat/pages/authorization/login.dart';
import 'package:decideat/widgets/bottomNavBar.dart';
import 'package:decideat/widgets/navigationProfileAppBar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/main.dart';
import 'package:decideat/pages/profile/settings/about/terms_of_service.dart';
import 'package:decideat/pages/profile/settings/privacy/privacy_policy.dart';
import 'package:decideat/pages/profile/settings/privacy/privacy_settings.dart';
import 'package:decideat/pages/profile/settings/account/profile_information.dart';
import 'package:decideat/pages/profile/settings/account/email.dart';
import 'package:decideat/pages/profile/settings/account/password.dart';
import 'package:decideat/pages/profile/settings/preferences/notifications.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true;
  bool darkModeEnabled = false;
  String selectedLanguage = 'English';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Locale currentLocale = Localizations.localeOf(context);
    // Update selectedLanguage based on the current locale.
    switch (currentLocale.languageCode) {
      case 'de':
        selectedLanguage = 'Deutsch';
        break;
      case 'pl':
        selectedLanguage = 'Polski';
        break;
      case 'es':
        selectedLanguage = 'Español';
        break;
      default:
        selectedLanguage = 'English';
    }
    // Set the dark mode switch based on the current theme brightness.
    darkModeEnabled = Theme.of(context).brightness == Brightness.dark;
  }

  // No local storage logic now—only dynamic locale change
  // Optionally remove _loadLanguage since it's not needed.

  // Called when a new language is selected
  void _changeLanguage(String newLanguage) {
    setState(() {
      selectedLanguage = newLanguage;
    });

    // Map language names to locale codes.
    final languageMap = {
      'English': 'en',
      'Deutsch': 'de',
      'Polski': 'pl',
      'Español': 'es',
    };

    final localeCode = languageMap[newLanguage] ?? 'en';
    // Update the app locale dynamically.
    MyApp.setLocale(context, Locale(localeCode));
  }

  // Show language dialog to allow user to select a language
  void _showLanguageDialog() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              onTap: () {
                _changeLanguage('English');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.languageChanged('English'))),
                );
              },
            ),
            ListTile(
              title: const Text('Deutsch'),
              onTap: () {
                _changeLanguage('Deutsch');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.languageChanged('Deutsch'))),
                );
              },
            ),
            ListTile(
              title: const Text('Polski'),
              onTap: () {
                _changeLanguage('Polski');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.languageChanged('Polski'))),
                );
              },
            ),
            ListTile(
              title: const Text('Español'),
              onTap: () {
                _changeLanguage('Español');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.languageChanged('Español'))),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.clearCache),
        content: Text(loc.clearCacheConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () {
              // Clear cache logic here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.cacheCleared)),
              );
            },
            child: Text(loc.clear),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.logOut),
        content: Text(loc.logoutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              logout(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.logoutSuccessful)),
              );
            },
            child: Text(loc.logOut),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: const NavigationProfileAppBar(currentPage: 'settings'),
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
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Account Section
            _buildSectionHeader(loc.account),
            _buildSettingsCard([
              _buildSettingsTile(
                loc.profileInformation,
                loc.updatePersonalInformation,
                Icons.person,
                onTap: () {
                  // Navigate to profile information page
                  Navigator.push(context, _createRouteToProfileInformationPage());
                },
              ),
              const Divider(),
              _buildSettingsTile(
                loc.email,
                loc.changeEmailAddress,
                Icons.email,
                onTap: () {
                  // Navigate to email change page
                  Navigator.push(context, _createRouteToEmailChangePage());

                },
              ),
              const Divider(),
              _buildSettingsTile(
                loc.password,
                loc.updatePassword,
                Icons.lock,
                onTap: () {
                  Navigator.push(context, _createRouteToPasswordChangePage());
                },
              ),
            ]),
            const SizedBox(height: 24),
            // Preferences Section
            _buildSectionHeader(loc.preferences),
            _buildSettingsCard([
              _buildSettingsTile(
                loc.notifications,
                loc.receiveUpdatesAndReminders,
                Icons.notifications,
                onTap: () {
                  // Navigate to notifications settings
                  Navigator.push(
                    context, 
                    _createRouteToNotificationsSettingsPage(),
                  );
                },
              ),
              const Divider(),
              _buildSwitchTile(
                loc.darkMode,
                loc.switchBetweenThemes,
                Icons.dark_mode,
                darkModeEnabled,
                (value) {
                  setState(() {
                    darkModeEnabled = value;
                  });
                  // Update the dark mode in MyApp.
                  MyApp.setDarkMode(context, value);
                },
              ),
              const Divider(),
              _buildDropdownTile(
                loc.language,
                loc.choosePreferredLanguage,
                Icons.language,
                selectedLanguage,
                ['English', 'Deutsch', 'Polski', 'Español'],
                (value) {
                  _changeLanguage(value!);
                },
              ),
            ]),
            const SizedBox(height: 24),
            // Privacy & Data Section
            _buildSectionHeader(loc.privacyAndData),
            _buildSettingsCard([
              _buildSettingsTile(
                loc.privacySettings,
                loc.manageDataSharingPreferences,
                Icons.security,
                onTap: () {
                  // Navigate to privacy settings
                  Navigator.push(
                    context, 
                    _createRouteToPrivacySettingsPage(),
                  );
                },
              ),
              const Divider(),
              _buildSettingsTile(
                loc.privacyPolicy,
                loc.readPrivacyPolicy,
                Icons.policy,
                onTap: () {
                  PrivacyPolicyPopUp(context);
                },
              ),

              // const Divider(),
              // _buildSettingsTile(
              //   loc.clearCache,
              //   loc.freeUpStorageSpace,
              //   Icons.cleaning_services,
              //   onTap: () {
              //     _showClearCacheDialog();
              //   },
              // ),
            ]),
            const SizedBox(height: 24),
            // About Section
            _buildSectionHeader(loc.about),
            _buildSettingsCard([
              _buildSettingsTile(
                loc.appVersion,
                '0.2.1',
                Icons.info,
              ),
              const Divider(),
              _buildSettingsTile(
                loc.termsOfService,
                loc.readTermsAndConditions,
                Icons.description,
                onTap: () {
                  TermsOfServicePopUp(context);
                },
              ),
              // const Divider(),
              // _buildSettingsTile(
              //   loc.privacyPolicy,
              //   loc.readPrivacyPolicy,
              //   Icons.policy,
              //   onTap: () {
              //     // Navigate to Privacy Policy page
              //   },
              // ),
            ]),
            const SizedBox(height: 24),
            // Log Out Button
            Center(
              child: SizedBox(
                width: 150,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showLogoutDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size(120, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(
                    Icons.logout,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(loc.logOut, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 4),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.green.shade800,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(String title, String subtitle, IconData icon,
      {VoidCallback? onTap}) {
    return ListTile(
      hoverColor: Colors.transparent,
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
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
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
        onChanged: onChanged,
        activeColor: Colors.green.shade400,
      ),
    );
  }

  Widget _buildDropdownTile(String title, String subtitle, IconData icon,
      String value, List<String> options, Function(String?) onChanged) {
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
      trailing: DropdownButton<String>(
        value: value,
        onChanged: onChanged,
        underline: const SizedBox(),
        items: options.map((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
      ),
    );
  }

  Route _createRouteToProfileInformationPage() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const ProfileInformationPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  Route _createRouteToEmailChangePage() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const EmailPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  Route _createRouteToPasswordChangePage() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PasswordPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  Route _createRouteToNotificationsSettingsPage() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const NotificationsSettingsPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  Route _createRouteToPrivacySettingsPage() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PrivacySettingsPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

void logout(context) async {
  // Replace with your token deletion logic
  await storage.delete(key: 'accessToken');
  await storage.delete(key: 'refreshToken');
  await storage.delete(key: 'userId');
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const LoginPage()),
  );
}
