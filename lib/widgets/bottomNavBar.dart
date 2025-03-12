//// filepath: /c:/Users/footb/Documents/GitHub/FrontEnd/lib/widgets/bottomNavBar.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../pages/planner.dart';
import '../pages/recipes.dart';
import '../pages/home.dart';
import '../pages/storage.dart';
import '../pages/profile.dart';

class BottomNavBar extends StatefulWidget {
  final int initialIndex;
  const BottomNavBar({Key? key, this.initialIndex = 2}) : super(key: key);

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  late int _selectedIndex;
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    // Only navigate if tapping a different item.
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    Widget destination;
    switch (index) {
      case 0:
        destination = const PlannerPage();
        break;
      case 1:
        destination = const RecipesPage();
        break;
      case 2:
        destination = const HomePage();
        break;
      case 3:
        destination = const StoragePage();
        break;
      case 4:
        destination = const ProfilePage();
        break;
      default:
        destination = const HomePage();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.calendar_today),
          label: loc.planner,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.menu_book),
          label: loc.recipes,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          label: loc.home,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.kitchen),
          label: loc.storage,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person),
          label: loc.profile,
        ),
      ],
    );
  }
}