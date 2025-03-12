import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../widgets/bottomNavBar.dart';
import 'friendNavigationAppBar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/api/api.dart' as api;
import 'package:decideat/api/recipe.dart';
import 'package:decideat/pages/recipes.dart'; // for RecipeCard widget

class FriendFavouritesPage extends StatefulWidget {
  final String userId;
  const FriendFavouritesPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<FriendFavouritesPage> createState() => _FriendFavouritesPageState();
}

class _FriendFavouritesPageState extends State<FriendFavouritesPage> {
  List<Recipe> favouriteRecipes = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchFriendFavouriteRecipes();
  }

  Future<void> fetchFriendFavouriteRecipes() async {
    try {
      // First refresh token if needed
      await api.RefreshTokenIfExpired();
      
      // Get access token for authentication
      String? token = await api.storage.read(key: "accessToken");
      
      if (token == null) {
        throw Exception('Not authenticated');
      }
      
      // Fetch friend's liked recipe IDs using the specified endpoint
      final likedResponse = await http.get(
        Uri.parse('${api.apiUrl}/user/liked-recipes/${widget.userId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (likedResponse.statusCode != 200) {
        throw Exception('Failed to load friend\'s liked recipes');
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
    final loc = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Adjust grid columns responsively
    int crossAxisCount = 2;
    if (screenWidth > 1200) {
      crossAxisCount = 4;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
    }
    
    return Scaffold(
      appBar: FriendNavigationAppBar(
        currentPage: 'favourites',
        friendId: widget.userId,
      ),
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
                                // Just trigger a rebuild to reflect any UI changes
                                setState(() {});
                              },
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            "No favourite recipes yet",
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
        ),
      ),
      // bottomNavigationBar: const BottomNavBar(initialIndex: 4),
    );
  }
} 