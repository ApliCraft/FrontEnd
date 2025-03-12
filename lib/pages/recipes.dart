//// filepath: /C:/Users/footb/Documents/GitHub/FrontEnd/lib/pages/recipes.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:decideat/api/api.dart';
import 'package:decideat/api/recipe.dart';
import 'package:decideat/pages/recipes/recipe.dart';
import 'package:decideat/widgets/bottomNavBar.dart';
import 'package:decideat/widgets/navigation_recipes_appbar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:decideat/pages/recipes/filter_menu.dart';
// import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:convert';

final storage = const FlutterSecureStorage();

class RecipesPage extends StatefulWidget {
  const RecipesPage({Key? key}) : super(key: key);

  @override
  _RecipesPageState createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  // Search query variable
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Map to store recipes by category
  Map<String, List<Recipe>> recipesByCategory = {
    'Breakfast': [],
    'Lunch': [],
    'Dinner': [],
    'Snack': []
  };
  
  // Active category for filter
  String _activeCategory = 'All';
  
  // Loading states
  bool isLoading = true;
  String? errorMessage;
  
  // Scroll controller and header visibility
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;

  // Sort and filter options
  String _sortBy = 'likes'; // Sorting options: 'likes', 'alphabetical', 'calories'
  bool _showVegetarian = false;
  bool _showVegan = false;
  bool _showGlutenFree = false;
  bool _showDairyFree = false;
  int _maxPrepTime = 120; // Maximum preparation time in minutes

  @override
  void initState() {
    super.initState();
    fetchRecipes();
    
    // Add scroll listener
    _scrollController.addListener(_scrollListener);
  }
  
  // Scroll listener to show/hide header based on scroll direction
  void _scrollListener() {
    final currentPosition = _scrollController.position.pixels;
    
    // Determine scroll direction based on position change
    if (currentPosition > _lastScrollPosition + 5) {
      // Scrolling down by a significant amount
      if (_isHeaderVisible) {
        setState(() {
          _isHeaderVisible = false;
        });
      }
    } else if (currentPosition < _lastScrollPosition - 5) {
      // Scrolling up by a significant amount
      if (!_isHeaderVisible) {
        setState(() {
          _isHeaderVisible = true;
        });
      }
    }
    
    // Update last position
    _lastScrollPosition = currentPosition;
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Fetch recipes for all categories
  Future<void> fetchRecipes() async {
    try {
      setState(() {
        isLoading = true;
        // Clear existing recipes when refreshing
        for (String category in recipesByCategory.keys) {
          recipesByCategory[category] = [];
        }
      });
      
      // Refresh token if needed
      await RefreshTokenIfExpired();
      
      // Get access token
      String? token = await storage.read(key: "accessToken");

      // First, fetch the user's liked recipes to keep track of like status
      Set<String> likedRecipeIds = await _fetchLikedRecipeIds(token);
      
      // If "All" category is selected, fetch all categories
      if (_activeCategory == 'All') {
        // Iterate through each category and fetch its recipes
        for (String category in recipesByCategory.keys) {
          fetchRecipesByCategory(category, token, likedRecipeIds);
        }
      } else {
        // Fetch only the selected category
        fetchRecipesByCategory(_activeCategory, token, likedRecipeIds);
      }
      
      // We're setting isLoading to false inside each category's fetch method
      
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading recipes: $e';
        isLoading = false;
      });
    }
  }

  // Helper method to fetch user's liked recipe IDs
  Future<Set<String>> _fetchLikedRecipeIds(String? token) async {
    Set<String> likedIds = {};
    
    if (token == null) return likedIds;
    
    try {
      final likedResponse = await http.post(
        Uri.parse('$apiUrl/recipe/get-liked-recipes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (likedResponse.statusCode == 200) {
        final List<dynamic> likedRecipeIds = json.decode(likedResponse.body);
        likedIds = likedRecipeIds.map((id) => id.toString()).toSet();
        print('Fetched ${likedIds.length} liked recipes');
      } else {
        print('Failed to fetch liked recipes: ${likedResponse.statusCode}');
      }
    } catch (e) {
      print('Error fetching liked recipes: $e');
    }
    
    return likedIds;
  }
  
  // Fetch recipes for a specific category
  Future<void> fetchRecipesByCategory(String category, String? token, Set<String> likedRecipeIds) async {
    try {
      print('Fetching recipes for category: $category');
      
      // First, get IDs for recipes in this category
      final idsResponse = await http.post(
        Uri.parse('$apiUrl/recipe/get-ids-by-params'),
        headers: {
          'Content-Type': 'application/json',
          // 'Authorization': token != null ? 'Bearer $token' : '',
        },
        body: jsonEncode({
          'category': category
        }),
      );
      
      if (idsResponse.statusCode != 200) {
        print('Failed to load recipe IDs for $category: ${idsResponse.statusCode} - ${idsResponse.body}');
        throw Exception('Failed to load recipe IDs for $category: ${idsResponse.statusCode}');
      }
      
      final List<dynamic> recipesData = json.decode(idsResponse.body);
      print('Found ${recipesData.length} recipes for category $category');
      
      // Initialize empty list for this category if it doesn't exist
      if (!recipesByCategory.containsKey(category)) {
        setState(() {
          recipesByCategory[category] = [];
        });
      }
      
      // Process recipes concurrently but update UI for each one as it completes
      for (var recipeData in recipesData) {
        if (recipeData == null || !recipeData.containsKey('_id')) {
          print('Invalid recipe data: $recipeData');
          continue;
        }
        
        final String recipeId = recipeData['_id'];
        print('Fetching details for recipe ID: $recipeId');
        
        // Fetch and process each recipe individually
        fetchAndAddSingleRecipe(recipeId, category, token, likedRecipeIds);
      }
      
      // Set loading to false after initiating all fetch operations
      setState(() {
        isLoading = false;
      });
      
    } catch (e) {
      print('Error fetching recipes for $category: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // Fetch and add a single recipe, updating UI immediately
  Future<void> fetchAndAddSingleRecipe(String recipeId, String category, String? token, Set<String> likedRecipeIds) async {
    try {
      final recipeResponse = await http.get(
        Uri.parse('$apiUrl/recipe/$recipeId'),
        headers: {
          'Content-Type': 'application/json',
          // 'Authorization': token != null ? 'Bearer $token' : '',
        },
      );
      
      if (recipeResponse.statusCode == 200) {
        final recipeFullData = json.decode(recipeResponse.body);
        try {
          final recipe = Recipe.fromJson(recipeFullData);
          
          // Check if this recipe is liked by the user
          recipe.isLiked = likedRecipeIds.contains(recipe.id);
          
          // Update UI immediately after each recipe is loaded
          setState(() {
            if (!recipesByCategory.containsKey(category)) {
              recipesByCategory[category] = [];
            }
            recipesByCategory[category]!.add(recipe);
          });
          
          print('Successfully added recipe: ${recipe.recipeName} (Liked: ${recipe.isLiked})');
        } catch (e) {
          print('Error parsing recipe: $e');
          print('Recipe data: $recipeFullData');
        }
      } else {
        print('Failed to fetch recipe $recipeId: ${recipeResponse.statusCode} - ${recipeResponse.body}');
      }
    } catch (e) {
      print('Error fetching single recipe $recipeId: $e');
    }
  }

  // Get all recipes for display
  List<Recipe> get allRecipes {
    if (_activeCategory == 'All') {
      // Combine all recipes from all categories
      List<Recipe> all = [];
      for (var recipes in recipesByCategory.values) {
        all.addAll(recipes);
      }
      return all;
    } else if (recipesByCategory.containsKey(_activeCategory)) {
      // Return recipes from the selected category
      return recipesByCategory[_activeCategory] ?? [];
    }
    return [];
  }
  
  // Filter recipes based on search query and filter options
  List<Recipe> get filteredRecipes {
    List<Recipe> filtered = allRecipes.where((recipe) {
      // Apply search filter
      final searchMatch = _searchQuery.isEmpty || 
        recipe.recipeName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (recipe.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      // Apply diet filters
      bool dietMatch = true;
      if (_showVegetarian) {
        dietMatch = dietMatch && !_containsMeat(recipe);
      }
      if (_showVegan) {
        dietMatch = dietMatch && !_containsAnimalProducts(recipe);
      }
      if (_showGlutenFree) {
        dietMatch = dietMatch && !_containsGluten(recipe);
      }
      if (_showDairyFree) {
        dietMatch = dietMatch && !_containsDairy(recipe);
      }
      
      // Apply preparation time filter - don't filter if set to max value
      final prepTimeMatch = _maxPrepTime == 120 || recipe.prepareTime <= _maxPrepTime;
      
      return searchMatch && dietMatch && prepTimeMatch;
    }).toList();
    
    // Apply sorting
    switch(_sortBy) {
      case 'likes':
        filtered.sort((a, b) => b.likes.compareTo(a.likes));
        break;
      case 'alphabetical':
        filtered.sort((a, b) => a.recipeName.compareTo(b.recipeName));
        break;
      case 'calories':
        filtered.sort((a, b) => a.kcalPortion.compareTo(b.kcalPortion));
        break;
      case 'prepTime':
        filtered.sort((a, b) => a.prepareTime.compareTo(b.prepareTime));
        break;
    }
    
    return filtered;
  }
  
  // Helper method to check if a recipe contains meat
  bool _containsMeat(Recipe recipe) {
    final fullText = '${recipe.recipeName} ${recipe.description} ${recipe.preparation}'.toLowerCase();
    
    return fullText.contains('meat') || 
           fullText.contains('beef') || 
           fullText.contains('chicken') || 
           fullText.contains('pork') ||
           fullText.contains('fish') ||
           fullText.contains('seafood') ||
           fullText.contains('salmon') ||
           fullText.contains('tuna');
  }
  
  // Helper method to check if a recipe contains animal products
  bool _containsAnimalProducts(Recipe recipe) {
    return _containsMeat(recipe) || _containsDairy(recipe) ||
           '${recipe.recipeName} ${recipe.description} ${recipe.preparation}'.toLowerCase().contains('egg');
  }
  
  // Helper method to check if a recipe contains gluten
  bool _containsGluten(Recipe recipe) {
    final fullText = '${recipe.recipeName} ${recipe.description} ${recipe.preparation}'.toLowerCase();
    
    return fullText.contains('gluten') || 
           fullText.contains('wheat') || 
           fullText.contains('barley') || 
           fullText.contains('rye') ||
           fullText.contains('flour') ||
           fullText.contains('pasta') ||
           fullText.contains('bread');
  }
  
  // Helper method to check if a recipe contains dairy
  bool _containsDairy(Recipe recipe) {
    final fullText = '${recipe.recipeName} ${recipe.description} ${recipe.preparation}'.toLowerCase();
    
    return fullText.contains('milk') || 
           fullText.contains('cheese') || 
           fullText.contains('yogurt') || 
           fullText.contains('dairy') ||
           fullText.contains('cream') ||
           fullText.contains('butter');
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 800;
    
    return Scaffold(
      appBar: NavigationRecipesAppBar(currentPage: 'recipes'),
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
        child: Column(
          children: [
            // Animated header (search bar + category selector)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _isHeaderVisible ? 126 : 0,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: _buildSearchBar(isLargeScreen),
                    ),
                    // Category selector
                    _buildCategorySelector(),
                  ],
                ),
              ),
            ),
            
            // Recipe grid or loading indicator
            Expanded(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                  ? Center(child: Text(errorMessage!))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildRecipesGrid(),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 1),
    );
  }

  Widget _buildSearchBar(bool isLargeScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search recipes...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.grey),
            onPressed: () => _showFilterBottomSheet(context),
            tooltip: 'Filter recipes',
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
  
  Widget _buildCategorySelector() {
    final categories = ['All', ...recipesByCategory.keys.toList()];
    
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isActive = _activeCategory == category;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeCategory = category;
                // Reload recipes with the new category filter
                fetchRecipes();
              });
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 0, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.black87,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecipesGrid() {
    // Determine number of columns based on screen size
    int crossAxisCount;
    if (MediaQuery.of(context).size.width > 1200) {
      crossAxisCount = 5;
    } else if (MediaQuery.of(context).size.width > 800) {
      crossAxisCount = 4;
    } else if (MediaQuery.of(context).size.width > 500) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }
    
    final recipes = filteredRecipes;
    
    return recipes.isEmpty
        ? Center(
            child: Text(
              'No recipes found for $_activeCategory',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          )
        : GridView.builder(
            controller: _scrollController, // Add scroll controller for header behavior
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.65, // Reduced from 0.75 to make cards taller
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return RecipeCard(
                recipe: recipe,
                onUpdate: () {
                  // Update the UI for just this recipe, without reloading all recipes
                  setState(() {
                    // This triggers a rebuild with the updated recipe state
                  });
                },
              );
            },
          );
  }

  Widget _buildFilterMenu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters & Sort',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          const Text(
            'Allergens',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          CheckboxListTile(
            title: const Text('Gluten-Free'),
            value: glutenFree,
            onChanged: (value) =>
                setState(() => glutenFree = value ?? false),
          ),
          CheckboxListTile(
            title: const Text('Dairy-Free'),
            value: dairyFree,
            onChanged: (value) => setState(() => dairyFree = value ?? false),
          ),
          const SizedBox(height: 16),
          const Text(
            'Diets',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          CheckboxListTile(
            title: const Text('Vegan'),
            value: vegan,
            onChanged: (value) => setState(() => vegan = value ?? false),
          ),
          CheckboxListTile(
            title: const Text('Vegetarian'),
            value: vegetarian,
            onChanged: (value) =>
                setState(() => vegetarian = value ?? false),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Apply filters and refresh recipes
              fetchRecipes();
            },
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }

  // Method to show filter overlay (we'll replace this with the bottom sheet)
  void _showFilterOverlay(BuildContext context) {
    _showFilterBottomSheet(context); // Replace dialog with bottom sheet
  }
  
  // Filter bottom sheet
  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sort & Filter',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Sort by options
                    const Text(
                      'Sort by',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Radio buttons for sort options
                    RadioListTile<String>(
                      title: const Text('Most Liked'),
                      value: 'likes',
                      groupValue: _sortBy,
                      onChanged: (value) {
                        setModalState(() {
                          _sortBy = value!;
                        });
                        setState(() {});
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Alphabetical (A-Z)'),
                      value: 'alphabetical',
                      groupValue: _sortBy,
                      onChanged: (value) {
                        setModalState(() {
                          _sortBy = value!;
                        });
                        setState(() {});
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Lowest Calories'),
                      value: 'calories',
                      groupValue: _sortBy,
                      onChanged: (value) {
                        setModalState(() {
                          _sortBy = value!;
                        });
                        setState(() {});
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Quickest Preparation'),
                      value: 'prepTime',
                      groupValue: _sortBy,
                      onChanged: (value) {
                        setModalState(() {
                          _sortBy = value!;
                        });
                        setState(() {});
                      },
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Dietary filters
                    const Text(
                      'Dietary Preferences',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    SwitchListTile(
                      title: const Text('Vegetarian'),
                      value: _showVegetarian,
                      onChanged: (value) {
                        setModalState(() {
                          _showVegetarian = value;
                        });
                        setState(() {});
                      },
                    ),
                    
                    SwitchListTile(
                      title: const Text('Vegan'),
                      value: _showVegan,
                      onChanged: (value) {
                        setModalState(() {
                          _showVegan = value;
                        });
                        setState(() {});
                      },
                    ),
                    
                    SwitchListTile(
                      title: const Text('Gluten-Free'),
                      value: _showGlutenFree,
                      onChanged: (value) {
                        setModalState(() {
                          _showGlutenFree = value;
                        });
                        setState(() {});
                      },
                    ),
                    
                    SwitchListTile(
                      title: const Text('Dairy-Free'),
                      value: _showDairyFree,
                      onChanged: (value) {
                        setModalState(() {
                          _showDairyFree = value;
                        });
                        setState(() {});
                      },
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Preparation time slider
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maximum Preparation Time: ${_maxPrepTime == 120 ? "Unlimited" : "$_maxPrepTime minutes"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: _maxPrepTime.toDouble(),
                          min: 10,
                          max: 120,
                          divisions: 11,
                          label: _maxPrepTime == 120 ? "Unlimited" : "$_maxPrepTime min",
                          onChanged: (value) {
                            setModalState(() {
                              _maxPrepTime = value.toInt();
                            });
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Apply and Reset buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _sortBy = 'likes';
                              _showVegetarian = false;
                              _showVegan = false;
                              _showGlutenFree = false;
                              _showDairyFree = false;
                              _maxPrepTime = 120;
                            });
                            setState(() {});
                          },
                          child: const Text('Reset'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Apply Filters'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Filter options
bool glutenFree = false;
bool dairyFree = false;
bool vegan = false;
bool vegetarian = false;

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onUpdate;

  const RecipeCard({
    Key? key,
    required this.recipe,
    this.onUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if recipe is private
    bool isPrivate = recipe.privacy.toLowerCase() == 'private';
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  RecipePage(recipeId: recipe.id),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      FadeTransition(
                opacity: animation,
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ).then((likeStatusChanged) {
            // If like status changed in the recipe detail page
            if (likeStatusChanged == true) {
              // Refresh the like status by checking liked recipes again
              _refreshRecipeLikeStatus(context);
              // Call the onUpdate callback to refresh UI
              if (onUpdate != null) {
                onUpdate!();
              }
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe image with category tag
            Stack(
              children: [
                // Recipe image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 1.2,
                    child: StreamBuilder<FileResponse>(
                      stream: DefaultCacheManager().getFileStream(
                        '$apiUrl/images/${recipe.photo['fileName']}',
                        withProgress: true,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          var fileInfo = snapshot.data;
                          if (fileInfo is DownloadProgress) {
                            return Center(
                              child: CircularProgressIndicator(
                                value: fileInfo.progress,
                              ),
                            );
                          } else if (fileInfo is FileInfo) {
                            return Image.file(
                              fileInfo.file,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            );
                          }
                        }
                        return Center(child: Icon(Icons.image, color: Colors.grey.shade400, size: 40));
                      },
                    ),
                  ),
                ),
                // Category tag
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      recipe.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Time tag
                Positioned(
                  top: 40,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.white, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          '${recipe.prepareTime} min',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Vertical Like and share buttons
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    children: [
                      // Like button
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: InkWell(
                          onTap: () async {
                            await UpdateLikeCount(recipe, context);
                          },
                          child: Icon(
                            recipe.isLiked ? Icons.favorite : Icons.favorite_border,
                            color: recipe.isLiked ? Colors.red.shade400 : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      // Like count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        margin: const EdgeInsets.only(top: 2, bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${recipe.likes}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Share button
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: InkWell(
                          onTap: () {
                            Share.share('Check out this recipe: ${recipe.recipeName}');
                          },
                          child: const Icon(
                            Icons.share,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Display excluded diets tag on bottom right
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: _buildExcludedDietsTag(recipe),
                ),
                // Privacy indicator
                if (isPrivate)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, color: Colors.white, size: 10),
                          const SizedBox(width: 2),
                          const Text(
                            'Private',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Recipe details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe name
                  Text(
                    recipe.recipeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Author
                  if (recipe.author.isNotEmpty)
                    SizedBox(
                      height: 12,
                      child: Text(
                        'by ${recipe.author.join(", ")}',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Nutrition data with larger text
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.2),
                      1: FlexColumnWidth(1.2),
                    },
                    children: [
                      TableRow(
                        children: [
                          // Calories
                          Row(
                            children: [
                              Icon(Icons.local_fire_department, size: 14, color: Colors.deepOrange),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  '${recipe.kcalPortion} kcal',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          // Protein
                          Row(
                            children: [
                              Icon(Icons.fitness_center, size: 14, color: Colors.purple),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  '${recipe.proteinPortion}g protein',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          // Fat
                          Row(
                            children: [
                              Icon(Icons.opacity, size: 14, color: Colors.lightBlue),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  '${recipe.fatContentPortion}g fat',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          // Carbs
                          Row(
                            children: [
                              Icon(Icons.grain, size: 14, color: Colors.amber.shade700),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  '${recipe.carbohydratesPortion}g carbs',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Add more space before allergens
                  const SizedBox(height: 8),
                  
                  // Allergens info with larger size
                  if (_hasAllergens(recipe))
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _getAllergensText(recipe),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to check if recipe has allergens
  bool _hasAllergens(Recipe recipe) {
    final fullText = '${recipe.recipeName} ${recipe.description} ${recipe.preparation}'.toLowerCase();
    
    return fullText.contains('milk') || 
           fullText.contains('cheese') || 
           fullText.contains('yogurt') || 
           fullText.contains('dairy') ||
           fullText.contains('cream') ||
           fullText.contains('nut') || 
           fullText.contains('peanut') || 
           fullText.contains('almond') || 
           fullText.contains('cashew') ||
           fullText.contains('hazelnut') ||
           fullText.contains('gluten') || 
           fullText.contains('wheat') || 
           fullText.contains('barley') || 
           fullText.contains('rye') ||
           fullText.contains('bread') ||
           fullText.contains('egg') ||
           fullText.contains('soy') || 
           fullText.contains('tofu') ||
           fullText.contains('fish') || 
           fullText.contains('salmon') || 
           fullText.contains('tuna') || 
           fullText.contains('seafood');
  }
  
  // Helper method to get allergens text
  String _getAllergensText(Recipe recipe) {
    final allergens = _getAllergensList(recipe);
    if (allergens.isEmpty) return 'No common allergens';
    return 'Contains: ${allergens.join(", ")}';
  }
  
  // Helper method to build excluded diets tag
  Widget _buildExcludedDietsTag(Recipe recipe) {
    final excludedDiets = _getExcludedDiets(recipe);
    if (excludedDiets.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Not for ${excludedDiets.first}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  // Helper method to get allergens list
  List<String> _getAllergensList(Recipe recipe) {
    List<String> allergens = [];
    final fullText = '${recipe.recipeName} ${recipe.description} ${recipe.preparation}'.toLowerCase();
    
    if (fullText.contains('milk') || 
        fullText.contains('cheese') || 
        fullText.contains('yogurt') || 
        fullText.contains('dairy') ||
        fullText.contains('cream')) {
      allergens.add('Dairy');
    }
    
    if (fullText.contains('nut') || 
        fullText.contains('peanut') || 
        fullText.contains('almond') || 
        fullText.contains('cashew') ||
        fullText.contains('hazelnut')) {
      allergens.add('Nuts');
    }
    
    if (fullText.contains('gluten') || 
        fullText.contains('wheat') || 
        fullText.contains('barley') || 
        fullText.contains('rye') ||
        fullText.contains('bread')) {
      allergens.add('Gluten');
    }
    
    if (fullText.contains('egg')) {
      allergens.add('Eggs');
    }
    
    if (fullText.contains('soy') || fullText.contains('tofu')) {
      allergens.add('Soy');
    }
    
    if (fullText.contains('fish') || 
        fullText.contains('salmon') || 
        fullText.contains('tuna') || 
        fullText.contains('seafood')) {
      allergens.add('Fish');
    }
    
    return allergens;
  }
  
  // Helper method to get excluded diets
  List<String> _getExcludedDiets(Recipe recipe) {
    List<String> excludedDiets = [];
    final fullText = '${recipe.recipeName} ${recipe.description} ${recipe.preparation}'.toLowerCase();
    
    // If contains meat, fish, or dairy, it's not vegan
    if (fullText.contains('meat') || 
        fullText.contains('beef') || 
        fullText.contains('chicken') || 
        fullText.contains('pork') ||
        fullText.contains('fish') ||
        fullText.contains('salmon') ||
        fullText.contains('tuna') ||
        fullText.contains('milk') ||
        fullText.contains('cheese') ||
        fullText.contains('yogurt') ||
        fullText.contains('cream')) {
      excludedDiets.add('Vegans');
    }
    
    // If contains meat or fish, it's not vegetarian
    if (fullText.contains('meat') || 
        fullText.contains('beef') || 
        fullText.contains('chicken') || 
        fullText.contains('pork') ||
        fullText.contains('fish') ||
        fullText.contains('salmon') ||
        fullText.contains('tuna')) {
      excludedDiets.add('Vegetarians');
    }
    
    // If contains gluten, it's not gluten-free
    if (fullText.contains('gluten') || 
        fullText.contains('wheat') || 
        fullText.contains('barley') || 
        fullText.contains('rye') ||
        fullText.contains('bread')) {
      excludedDiets.add('Gluten-Free Diet');
    }
    
    return excludedDiets;
  }

  Future<void> UpdateLikeCount(
      Recipe recipe, BuildContext context) async {
    try {
      // Refresh token if needed before making API calls
      await RefreshTokenIfExpired();
      
      // Get fresh access token
      final String? token = await storage.read(key: "accessToken");
      if (token == null) {
        print("No access token found");
        return;
      }
      
      // Store the original like state to revert if needed
      final bool wasLiked = recipe.isLiked;
      final int originalLikes = recipe.likes;
      
      // Optimistically update UI based on current state
      recipe.isLiked = !wasLiked;
      recipe.likes = wasLiked ? recipe.likes - 1 : recipe.likes + 1;
      
      // Call the onUpdate callback immediately for UI refresh
      if (onUpdate != null) onUpdate!();
      
      // Determine the URL based on the action
      final String endpoint = wasLiked 
          ? '$apiUrl/recipe/${recipe.id}/delete-like-count'  // Unliking
          : '$apiUrl/recipe/${recipe.id}/update-like-count'; // Liking
      
      // Make API request
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );
      
      // Handle response
      if (response.statusCode != 200) {
        print("Failed to update like status: ${response.statusCode} - ${response.body}");
        
        // Revert optimistic update if the request failed
        recipe.isLiked = wasLiked;
        recipe.likes = originalLikes;
        
        // Call the onUpdate callback to reflect the reverted state
        if (onUpdate != null) onUpdate!();
        
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${wasLiked ? 'unlike' : 'like'} recipe'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        print("Recipe ${wasLiked ? 'unliked' : 'liked'} successfully");
        
        // Force rebuild of the UI to ensure like icon color is correct
        if (onUpdate != null) onUpdate!();
      }
    } catch (e) {
      print("Error updating like status: $e");
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update like status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to refresh the like status for this recipe
  void _refreshRecipeLikeStatus(BuildContext context) async {
    try {
      // Refresh token if needed
      await RefreshTokenIfExpired();
      
      // Get fresh token
      String? token = await storage.read(key: "accessToken");
      if (token == null) return;
      
      // Get liked recipes
      final likedResponse = await http.post(
        Uri.parse('$apiUrl/recipe/get-liked-recipes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (likedResponse.statusCode == 200) {
        final List<dynamic> likedRecipeIds = json.decode(likedResponse.body);
        // Update the recipe's liked status
        final bool isLiked = likedRecipeIds.contains(recipe.id);
        
        // Update the recipe object
        if (recipe.isLiked != isLiked) {
          recipe.isLiked = isLiked;
          
          // Get updated like count
          final recipeResponse = await http.get(
            Uri.parse('$apiUrl/recipe/${recipe.id}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
          
          if (recipeResponse.statusCode == 200) {
            final data = json.decode(recipeResponse.body);
            recipe.likes = data['likes'] is int ? data['likes'] : 
                           data['likes'] is String ? int.tryParse(data['likes']) ?? 0 : 0;
          }
        }
      }
    } catch (e) {
      print('Error refreshing like status: $e');
    }
  }
}