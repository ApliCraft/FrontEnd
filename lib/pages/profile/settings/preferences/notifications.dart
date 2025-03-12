import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/widgets/bottomNavBar.dart';
import 'package:decideat/notifications/notifications_service.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({Key? key}) : super(key: key);

  @override
  _NotificationsSettingsPageState createState() => _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  bool _allNotifications = true;
  bool _mealReminders = true;
  bool _fluidReminders = true;
  bool _shoppingListReminders = true;
  bool _friendRequests = true;
  final NotificationsService _notificationsService = NotificationsService();
  
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }
  
  Future<void> _initializeNotifications() async {
    await _notificationsService.initNotifications();
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
                loc.notifications,
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
                    _buildMasterSwitchTile(
                      loc.allNotifications,
                      loc.enableAllNotifications,
                      Icons.notifications,
                      _allNotifications,
                      (value) {
                        setState(() {
                          _allNotifications = value;
                          // When master switch is toggled, update all other switches
                          if (!value) {
                            _mealReminders = false;
                            _fluidReminders = false;
                            _shoppingListReminders = false;
                            _friendRequests = false;
                          }
                        });
                      },
                    ),
                    const Divider(),
                    _buildSwitchTile(
                      loc.mealReminders,
                      loc.receiveMealReminders,
                      Icons.restaurant,
                      _mealReminders,
                      (value) {
                        setState(() {
                          _mealReminders = value;
                          _updateMasterSwitch();
                        });
                        _showTestNotification(context, loc.mealReminderTest);
                      },
                      enabled: _allNotifications,
                    ),
                    const Divider(),
                    _buildSwitchTile(
                      loc.fluidReminders,
                      loc.receiveFluidReminders,
                      Icons.local_drink,
                      _fluidReminders,
                      (value) {
                        setState(() {
                          _fluidReminders = value;
                          _updateMasterSwitch();
                        });
                        _showTestNotification(context, loc.fluidReminderTest);
                      },
                      enabled: _allNotifications,
                    ),
                    const Divider(),
                    _buildSwitchTile(
                      loc.shoppingListReminders,
                      loc.receiveShoppingListReminders,
                      Icons.shopping_cart,
                      _shoppingListReminders,
                      (value) {
                        setState(() {
                          _shoppingListReminders = value;
                          _updateMasterSwitch();
                        });
                        _showTestNotification(context, loc.shoppingListReminderTest);
                      },
                      enabled: _allNotifications,
                    ),
                    const Divider(),
                    _buildSwitchTile(
                      loc.friendRequests,
                      loc.receiveFriendRequestNotifications,
                      Icons.people,
                      _friendRequests,
                      (value) {
                        setState(() {
                          _friendRequests = value;
                          _updateMasterSwitch();
                        });
                        _showTestNotification(context, loc.friendRequestTest);
                      },
                      enabled: _allNotifications,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                loc.notificationsDisclaimer,
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

  void _updateMasterSwitch() {
    if (_mealReminders || _fluidReminders || _shoppingListReminders || _friendRequests) {
      setState(() {
        _allNotifications = true;
      });
    }
  }

  void _showTestNotification(BuildContext context, String message) {
    if (_allNotifications) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.testNotification,
            onPressed: () {
              _sendTestNotification(context, message);
            },
          ),
        ),
      );
    }
  }

  Future<void> _sendTestNotification(BuildContext context, String message) async {
    if (_allNotifications) {
      await _notificationsService.showNotification(
        context: context,
        title: 'Decideat',
        body: message,
      );
    }
  }

  Widget _buildMasterSwitchTile(
      String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.green.shade800),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green.shade400,
      ),
    );
  }

  Widget _buildSwitchTile(
      String title, String subtitle, IconData icon, bool value, Function(bool) onChanged,
      {required bool enabled}) {
    return ListTile(
      enabled: enabled,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled ? Colors.green.shade50 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.green.shade800 : Colors.grey,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: enabled ? value : false,
        onChanged: enabled ? onChanged : null,
        activeColor: Colors.green.shade400,
      ),
    );
  }
}
