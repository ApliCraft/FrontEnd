import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../widgets/bottomNavBar.dart';
import 'friendNavigationAppBar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/api/api.dart';

class FriendFavouritesPage extends StatefulWidget {
  final String userId;
  const FriendFavouritesPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<FriendFavouritesPage> createState() => _FriendFavouritesPageState();
}

class _FriendFavouritesPageState extends State<FriendFavouritesPage> {
  List<Map<String, dynamic>> favouriteRecipes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavouriteRecipes();
  }

  Future<void> _loadFavouriteRecipes() async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/user/${widget.userId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        final List<dynamic> recipeIds = userData['likedRecipes'] is List 
            ? userData['likedRecipes'] 
            : [userData['likedRecipes']];
        List<Map<String, dynamic>> recipes = [];

        // Fetch detailed data for each recipe
        for (String recipeId in recipeIds) {
          final recipeResponse = await http.get(
            Uri.parse('$apiUrl/recipe/$recipeId'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
          );

          if (recipeResponse.statusCode == 200) {
            final recipeData = jsonDecode(recipeResponse.body);
            recipes.add({
              'id': recipeId,
              'name': recipeData['name'] ?? '',
              'imageUrl': '$apiUrl/${recipeData['imageUrl'] ?? 'images/default_recipe.png'}',
              'description': recipeData['description'] ?? '',
              'rating': recipeData['rating'] ?? 0.0,
            });
          }
        }

        setState(() {
          favouriteRecipes = recipes;
          isLoading = false;
        });
      } else {
        print('Failed to load user data');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading favourite recipes: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
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
        child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : favouriteRecipes.isEmpty
            ? Center(
                child: Text(
                  "No favourite recipes yet",
                  style: const TextStyle(fontSize: 18),
                ),
              )
            : ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: favouriteRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = favouriteRecipes[index];
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.network(
                              recipe['imageUrl'],
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recipe['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  recipe['description'],
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      recipe['rating'].toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 4),
    );
  }
} 