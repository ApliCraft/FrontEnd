//// filepath: /C:/Users/footb/Documents/GitHub/FrontEnd/lib/widgets/navigationProfileAppBar.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../pages/profile.dart';
import '../pages/profile/friends.dart';
import '../pages/profile/favourites.dart';
import '../pages/profile/settings.dart';

class NavigationProfileAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String
      currentPage; // e.g. 'profile', 'friends', 'favourites', 'settings'

  const NavigationProfileAppBar({Key? key, required this.currentPage})
      : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  TextStyle _navTextStyle(String page, AppLocalizations loc) {
    return TextStyle(
      color: Colors.black,
      fontWeight: currentPage == page ? FontWeight.bold : FontWeight.normal,
    );
  }

  Widget _getDestination(String page) {
    switch (page) {
      case 'profile':
        return const ProfilePage();
      case 'friends':
        return const FriendsPage();
      case 'favourites':
        return FavouritesPage();
      case 'settings':
        return const SettingsPage();
      default:
        return const ProfilePage();
    }
  }

  void _navigate(BuildContext context, String page) {
    if (currentPage != page) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              _getDestination(page),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // Build settings icon with circular highlight if currentPage is 'settings'
    Widget settingsIcon = currentPage == 'settings'
        ? const Icon(Icons.settings, color: Colors.black, size: 26)
        : const Icon(Icons.settings, color: Colors.black);

    return AppBar(
      backgroundColor: Colors.green.shade50,
      scrolledUnderElevation: 0.0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Navigation text buttons using localized labels.
          Row(
            children: [
              TextButton(
                onPressed: () => _navigate(context, 'profile'),
                child: Text(
                  loc.profile,
                  style: _navTextStyle('profile', loc),
                ),
              ),
              TextButton(
                onPressed: () => _navigate(context, 'friends'),
                child: Text(
                  loc.friends,
                  style: _navTextStyle('friends', loc),
                ),
              ),
              TextButton(
                onPressed: () => _navigate(context, 'favourites'),
                child: Text(
                  loc.favourites,
                  style: _navTextStyle('favourites', loc),
                ),
              ),
            ],
          ),
          // Settings icon with fade transition on tap
          IconButton(
            icon: settingsIcon,
            onPressed: () => _navigate(context, 'settings'),
          ),
        ],
      ),
    );
  }
}
