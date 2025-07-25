//// filepath: /C:/Users/footb/Documents/GitHub/vv2/FrontEnd/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:decideat/api/checkAPI.dart';
import 'package:decideat/pages/home.dart';
import 'package:decideat/pages/planner.dart';
import 'package:decideat/pages/recipes.dart';
import 'package:decideat/pages/storage.dart';
import 'package:decideat/pages/profile.dart';
import 'package:decideat/pages/profile/friends.dart';
import 'package:decideat/pages/profile/favourites.dart';
import 'package:decideat/pages/profile/settings.dart';
import 'package:decideat/pages/profile/edit_profile.dart';
import 'package:decideat/pages/recipes/recipe.dart';
import 'package:decideat/pages/chat/chat.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/notifications/notifications_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final storage = const FlutterSecureStorage();
final GlobalKey<_MyAppState> myAppKey = GlobalKey<_MyAppState>();

// Method channel to get time zone from native code.
const platform = MethodChannel('com.aplicraft.decideat/timezone');

Future<String> getLocalTimeZone() async {
  try {
    final String timeZone = await platform.invokeMethod('getTimeZone');
    print("Successfully got timezone: $timeZone");
    return timeZone;
  } on PlatformException catch (e) {
    print("Failed to get timezone: ${e.message}");
    return 'Europe/Warsaw'; // fallback if native call fails
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  
  final String timeZoneName = await getLocalTimeZone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));

  NotificationsService().initNotifications();
  await dotenv.load(fileName: ".env");
  runApp(MyApp(key: myAppKey));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  static Future<void> setLocale(BuildContext context, Locale newLocale) async {
    await myAppKey.currentState?.setLocale(newLocale);
  }

  @override
  _MyAppState createState() => _MyAppState();

  static Future<void> setDarkMode(BuildContext context, bool darkMode) async {
    final state = context.findAncestorStateOfType<_MyAppState>();
    if (state != null) {
      await state.setDarkMode(darkMode);
    }
  }
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    String? darkMode = await storage.read(key: 'darkMode');
    String? localeCode = await storage.read(key: 'localeCode');
    if (mounted) {
      setState(() {
        _isDarkMode = darkMode == 'true';
        if (localeCode != null) _locale = Locale(localeCode);
      });
    }
  }

  Future<void> setDarkMode(bool darkMode) async {
    setState(() {
      _isDarkMode = darkMode;
    });
    await storage.write(key: 'darkMode', value: darkMode.toString());
  }

  Future<void> setLocale(Locale locale) async {
    setState(() {
      _locale = locale;
    });
    await storage.write(key: 'localeCode', value: locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green, secondary: Colors.greenAccent),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            secondary: Colors.greenAccent,
            brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const CheckAPI(),
      routes: {
        '/planner': (context) => const PlannerPage(),
        '/recipes': (context) => const RecipesPage(),
        '/home': (context) => const HomePage(),
        '/fridge': (context) => const StoragePage(),
        '/profile': (context) => const ProfilePage(),
        '/friends': (context) => const FriendsPage(),
        '/favourites': (context) => FavouritesPage(),
        '/settings': (context) => const SettingsPage(),
        '/editProfile': (context) => const EditProfilePage(),
        '/recipe': (context) =>
            const RecipePage(recipeId: '675d879d90a3b1421c861377'),
        '/chat': (context) => const ChatPage(),
      },
    );
  }
}