//// filepath: /C:/Users/footb/Documents/GitHub/FrontEnd/lib/widgets/navigationPlannerAppBar.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../pages/planner.dart';
import '../pages/planner/shopping_list.dart';
import 'package:decideat/pages/planner/fluid_list.dart';
import 'package:decideat/pages/planner/health_data.dart';

class NavigationPlannerAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String currentPage;

  const NavigationPlannerAppBar({Key? key, required this.currentPage})
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
      case 'planner':
        return const PlannerPage();
      case 'shoppingList':
        return const ShoppingListPage();
      case 'fluidList':
        return FluidList();
      case 'healthData':
        return HealthData();
      default:
        return const PlannerPage();
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
                onPressed: () => _navigate(context, 'planner'),
                child: Text(
                  loc.planner,
                  style: _navTextStyle('planner'),
                ),
              ),
              TextButton(
                onPressed: () => _navigate(context, 'fluidList'),
                child: Text(
                  loc.fluidList,
                  style: _navTextStyle('fluidList'),
                ),
              ),
              TextButton(
                onPressed: () => _navigate(context, 'healthData'),
                child: Text(
                  "Health",
                  style: _navTextStyle('healthData'),
                ),
              ),
              TextButton(
                onPressed: () => _navigate(context, 'shoppingList'),
                child: Text(
                  loc.shoppingList,
                  style: _navTextStyle('shoppingList'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
