import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class NotificationsService {
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Initialize timezone data
  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  // Initialization of the Notifications Service
  Future<void> initNotifications() async {
    if (_isInitialized) return; // Notifications already initialized

    try {
      // Configure timezone
      await _configureLocalTimeZone();

      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const initializationSettingsIOS = DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false);

      // Initialization settings
      const InitializationSettings initializationSettings =
          InitializationSettings(
              android: initializationSettingsAndroid,
              iOS: initializationSettingsIOS);

      // Initialize the notifications plugin
      await notificationPlugin.initialize(initializationSettings);

      // Request permission after initialization
      final notificationPermissions = await notificationPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await notificationPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // Request exact alarm permissions for scheduled notifications on Android
      await notificationPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();

      _isInitialized = true;
    } catch (e) {
      print("Error initializing notifications: $e");
      _isInitialized = false;
    }
  }

  // Notification detail setup
  NotificationDetails notificationDetails(BuildContext context) {
    final loc = AppLocalizations.of(context);
    
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'decideat_main_channel',
        loc?.notificationChannelName ?? 'Notifications', // Use the correct localization key
        channelDescription: loc?.notificationChannelDescription ?? 'Receive updates and reminders',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  // Show notification
  Future<void> showNotification({
    required BuildContext context,
    int id = 0,
    String? title,
    String? body,
    String? payload
  }) async {
    if (!_isInitialized) {
      await initNotifications();
    }
    
    return notificationPlugin.show(
      id,
      title,
      body,
      notificationDetails(context),
      payload: payload,
    );
  }

  // Scheduled notification
  Future<void> scheduleNotification({
    required BuildContext context,
    int id = 1,
    required String? title,
    required String? body,
    String? payload,
    required DateTime scheduledDate
  }) async {
    if (!_isInitialized) {
      await initNotifications();
    }
    
    // Convert DateTime to TZDateTime
    tz.TZDateTime scheduledDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    return notificationPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDateTime,
      notificationDetails(context),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }
}
