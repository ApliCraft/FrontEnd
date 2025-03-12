import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'friend_profile.dart';
import 'friend_list.dart';
import 'favourites_recipes.dart';

class FriendNavigationAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String currentPage;
  final String friendId;

  const FriendNavigationAppBar({
    Key? key,
    required this.currentPage,
    required this.friendId,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AppBar(
      backgroundColor: Colors.green.shade50,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton(
            onPressed: currentPage == 'profile'
                ? null
                : () {
                    Navigator.pushReplacement(
                      context,
                      _createRoute(FriendProfilePage(id: friendId)),
                    );
                  },
            child: Text(
              loc.profile,
              style: TextStyle(
                color: currentPage == 'profile' ? Colors.black : Colors.grey,
                fontWeight: currentPage == 'profile'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          TextButton(
            onPressed: currentPage == 'friends'
                ? null
                : () {
                    Navigator.pushReplacement(
                      context,
                      _createRoute(FriendListPage(userId: friendId)),
                    );
                  },
            child: Text(
              loc.friends,
              style: TextStyle(
                color: currentPage == 'friends' ? Colors.black : Colors.grey,
                fontWeight: currentPage == 'friends'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          TextButton(
            onPressed: currentPage == 'favourites'
                ? null
                : () {
                    Navigator.pushReplacement(
                      context,
                      _createRoute(FriendFavouritesPage(userId: friendId)),
                    );
                  },
            child: Text(
              loc.favourites,
              style: TextStyle(
                color: currentPage == 'favourites' ? Colors.black : Colors.grey,
                fontWeight: currentPage == 'favourites'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 