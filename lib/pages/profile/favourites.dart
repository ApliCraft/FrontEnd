import 'package:flutter/material.dart';
import '../../widgets/bottomNavBar.dart';
import '../../widgets/navigationProfileAppBar.dart';
import 'package:decideat/api/recipe.dart';
import 'package:decideat/pages/recipes.dart'; // for RecipeCard widget
import 'package:decideat/api/api.dart' as api; // for apiUrl
import 'dart:convert';
import 'package:http/http.dart' as http;

class FavouritesPage extends StatefulWidget {
  const FavouritesPage({Key? key}) : super(key: key);

  @override
  _FavouritesPageState createState() => _FavouritesPageState();
}

class _FavouritesPageState extends State<FavouritesPage> {
  List<Recipe> favouriteRecipes = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchFavouriteRecipes();
  }

  Future<void> fetchFavouriteRecipes() async {
    try {
      // First refresh token if needed
      await api.RefreshTokenIfExpired();
      
      // Get access token for authentication
      String? token = await api.storage.read(key: "accessToken");
      
      if (token == null) {
        throw Exception('Not authenticated');
      }
      
      // Fetch liked recipe IDs
      final likedResponse = await http.post(
        Uri.parse('${api.apiUrl}/recipe/get-liked-recipes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (likedResponse.statusCode != 200) {
        throw Exception('Failed to load liked recipes');
      }

      final List<dynamic> likedRecipeIds = json.decode(likedResponse.body);
      
      // Fetch detailed recipe information for each ID
      List<Recipe> recipes = [];
      
      for (var recipeId in likedRecipeIds) {
        final recipeResponse = await http.get(
          Uri.parse('${api.apiUrl}/recipe/$recipeId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (recipeResponse.statusCode == 200) {
          final recipeData = json.decode(recipeResponse.body);
          final recipe = Recipe.fromJson(recipeData);
          // Explicitly mark the recipe as liked since it's in favorites
          recipe.isLiked = true;
          recipes.add(recipe);
        }
      }
      
      setState(() {
        favouriteRecipes = recipes;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading recipes: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Adjust grid columns responsively.
    int crossAxisCount = 2;
    if (screenWidth > 1200) {
      crossAxisCount = 4;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
    }

    return Scaffold(
      appBar: const NavigationProfileAppBar(currentPage: 'favourites'),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(child: Text(errorMessage!))
                  : favouriteRecipes.isNotEmpty
                      ? GridView.builder(
                          itemCount: favouriteRecipes.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.65,
                          ),
                          itemBuilder: (context, index) {
                            final recipe = favouriteRecipes[index];
                            return RecipeCard(
                              recipe: recipe,
                              onUpdate: () {
                                // Keep displaying the recipe even after unliking
                                // The recipe will remain visible until user manually refreshes
                                // or navigates away from the page
                                setState(() {
                                  // Just trigger a rebuild to reflect any UI changes
                                  // without removing the recipe from the list
                                });
                              },
                            );
                          },
                        )
                      : const Center(child: Text('No favourites saved.')),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 4),
    );
  }
}
