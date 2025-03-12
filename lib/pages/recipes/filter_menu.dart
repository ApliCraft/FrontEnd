//// filepath: /C:/Users/footb/Documents/GitHub/FrontEnd/lib/pages/filter_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FilterOverlayContent extends StatefulWidget {
  const FilterOverlayContent({Key? key}) : super(key: key);

  @override
  _FilterOverlayContentState createState() => _FilterOverlayContentState();
}

class _FilterOverlayContentState extends State<FilterOverlayContent> {
  bool glutenFree = false;
  bool dairyFree = false;
  bool vegan = false;
  bool vegetarian = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      // Use a transparent AppBar with a close button.
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(loc.filtersAndSort, style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            Text(
              loc.allergens,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              title: Text(loc.glutenFree),
              value: glutenFree,
              onChanged: (value) => setState(() => glutenFree = value ?? false),
            ),
            CheckboxListTile(
              title: Text(loc.dairyFree),
              value: dairyFree,
              onChanged: (value) => setState(() => dairyFree = value ?? false),
            ),
            const SizedBox(height: 16),
            Text(
              loc.diets,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              title: Text(loc.vegan),
              value: vegan,
              onChanged: (value) => setState(() => vegan = value ?? false),
            ),
            CheckboxListTile(
              title: Text(loc.vegetarian),
              value: vegetarian,
              onChanged: (value) => setState(() => vegetarian = value ?? false),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Apply filters logic.
                  Navigator.of(context).pop();
                },
                child: Text(loc.applyFilters),
              ),
            ),
          ],
        ),
      ),
    );
  }
}