import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../pages/recipes.dart';
import '../pages/recipes/products.dart';
import '../pages/profile/favourites.dart';

class NavigationRecipesAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String currentPage;

  const NavigationRecipesAppBar({Key? key, required this.currentPage})
      : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  TextStyle _navTextStyle(String page) {
    return TextStyle(
      color: Colors.black,
      fontWeight: currentPage == page ? FontWeight.bold : FontWeight.normal,
    );
  }

  Widget _getDestination(String page) {
    switch (page) {
      case 'recipes':
        return const RecipesPage();
      case 'products':
        return const ProductsPage();
      case 'favourites':
        return const FavouritesPage();
      default:
        return const RecipesPage();
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
    return AppBar(
      backgroundColor: Colors.green.shade50,
      scrolledUnderElevation: 0.0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => _navigate(context, 'recipes'),
                child: Text(
                  loc.recipes,
                  style: _navTextStyle('recipes'),
                ),
              ),
              // TextButton(
              //   onPressed: () => _navigate(context, 'favourites'),
              //   child: Text(
              //     loc.favourites,
              //     style: _navTextStyle('favourites'),
              //   ),
              // ),
              TextButton(
                onPressed: () => _navigate(context, 'products'),
                child: Text(
                  loc.products,
                  style: _navTextStyle('products'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
