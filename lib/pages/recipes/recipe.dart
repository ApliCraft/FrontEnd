//// filepath: /c:/Users/footb/Documents/GitHub/FrontEnd/lib/pages/recipe.dart
import 'package:flutter/material.dart';
import 'package:decideat/api/api.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';



final storage = const FlutterSecureStorage();

class RecipePage extends StatefulWidget {
  const RecipePage({Key? key, required this.recipeId}) : super(key: key);

  final String recipeId;

  @override
  _RecipePageState createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  Map<String, dynamic>? recipeData;
  bool isLoading = true;
  String? errorMessage;
  bool _showIngredients = true;
  bool _isLiked = false;
  int _likeCount = 0;
  // Track if the like status has changed, to inform parent screen
  bool _likeStatusChanged = false;
  // Portion size multiplier (1.0 = original recipe)
  double _portionMultiplier = 1.0;

  @override
  void initState() {
    super.initState();
    fetchRecipeData();
  }

  Future<void> fetchRecipeData() async {
    try {
      // First refresh token if needed
      await RefreshTokenIfExpired();
      
      // Get access token for authentication
      String? token = await storage.read(key: "accessToken");
      
      // Fetch recipe data
      final recipeResponse = await http.get(
        Uri.parse('$apiUrl/recipe/${widget.recipeId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token != null ? 'Bearer $token' : '',
        },
      );

      if (recipeResponse.statusCode != 200) {
        throw Exception('Failed to load recipe data');
      }

      final data = json.decode(recipeResponse.body);
      
      // Check if the recipe is liked by the user
      if (token != null) {
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
            final bool isLiked = likedRecipeIds.contains(widget.recipeId);
            
            setState(() {
              _isLiked = isLiked;
              recipeData = data;
              // Use likeQuantity instead of likes
              _likeCount = data['likeQuantity'] ?? 0;
              isLoading = false;
            });
          } else {
            setState(() {
              recipeData = data;
              // Use likeQuantity instead of likes
              _likeCount = data['likeQuantity'] ?? 0;
              isLoading = false;
            });
          }
        } catch (e) {
          print('Error checking liked status: $e');
          setState(() {
            recipeData = data;
            // Use likeQuantity instead of likes
            _likeCount = data['likeQuantity'] ?? 0;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          recipeData = data;
          // Use likeQuantity instead of likes
          _likeCount = data['likeQuantity'] ?? 0;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading recipe: $e';
        isLoading = false;
      });
    }
  }

  // Calculate nutritional value based on quantity per 100g
  double calculateNutrition(double? valueFor100g, dynamic quantity) {
    if (valueFor100g == null || quantity == null) return 0;
    double quantityValue = quantity is int ? quantity.toDouble() : 
                           quantity is double ? quantity : 0;
    // Apply portion multiplier to the quantity
    return (valueFor100g * quantityValue * _portionMultiplier) / 100;
  }

  // Update like count similar to the implementation in recipes.dart
  Future<void> _updateLikeCount() async {
    try {
      // Refresh token if needed before making API calls
      await RefreshTokenIfExpired();
      
      // Get fresh access token
      final String? token = await storage.read(key: "accessToken");
      if (token == null) {
        print("No access token found");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to be logged in to like recipes'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Store the original like state to revert if needed
      final bool wasLiked = _isLiked;
      final int originalLikes = _likeCount;
      
      // Optimistically update UI based on current state
      setState(() {
        _isLiked = !wasLiked;
        _likeCount = wasLiked ? _likeCount - 1 : _likeCount + 1;
        // Set flag that like status has changed
        _likeStatusChanged = true;
      });
      
      // Determine the URL based on the action
      final String endpoint = wasLiked 
          ? '$apiUrl/recipe/${widget.recipeId}/delete-like-count'  // Unliking
          : '$apiUrl/recipe/${widget.recipeId}/update-like-count'; // Liking
      
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
        setState(() {
          _isLiked = wasLiked;
          _likeCount = originalLikes;
          // Reset flag since we reverted
          _likeStatusChanged = false;
        });
        
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${wasLiked ? 'unlike' : 'like'} recipe'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        print("Recipe ${wasLiked ? 'unliked' : 'liked'} successfully");
        
        // Update the like count from response if available
        try {
          final responseData = json.decode(response.body);
          if (responseData != null && responseData['likeQuantity'] != null) {
            setState(() {
              _likeCount = responseData['likeQuantity'];
            });
          }
        } catch (e) {
          print("Could not parse like count from response: $e");
        }
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

  // Share recipe function
  void _shareRecipe() {
    if (recipeData == null) return;
    
    final String recipeName = recipeData!['name'] ?? 'Recipe';
    final String recipeDesc = recipeData!['preDescription'] ?? '';
    final String shareText = 'Check out this recipe: $recipeName\n\n$recipeDesc\n\nFound on DeciDeat!';
    
    Share.share(shareText);
  }

  // Increase portion size by 0.1
  void _increasePortion() {
    setState(() {
      _portionMultiplier += 0.1;
      // Round to 1 decimal place to avoid floating point issues
      _portionMultiplier = double.parse(_portionMultiplier.toStringAsFixed(1));
    });
  }

  // Decrease portion size by 0.1, with a minimum of 0.1
  void _decreasePortion() {
    if (_portionMultiplier > 0.1) {
      setState(() {
        _portionMultiplier -= 0.1;
        // Round to 1 decimal place to avoid floating point issues
        _portionMultiplier = double.parse(_portionMultiplier.toStringAsFixed(1));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isLargeScreen = MediaQuery.of(context).size.width >= 1400;

    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _likeStatusChanged),
          ),
        ),
        body: Center(child: Text(errorMessage!)),
      );
    }

    if (recipeData == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _likeStatusChanged),
          ),
        ),
        body: Center(child: Text('Recipe not found')),
      );
    }

    // Check if recipe is private
    final bool isPrivate = recipeData!['privacy']?.toString().toLowerCase() == 'private';
    
    // Get authors list - extract just usernames
    final List<dynamic> authors = recipeData!['author'] ?? [];
    final String authorText = authors.isNotEmpty 
        ? 'by ${authors.length > 1 
            ? "${authors.length} authors" 
            : authors.first['username'] ?? 'Unknown'}'
        : '';
    
    // Get prep time
    final int prepTime = recipeData!['prepareTime'] ?? 0;

    // The original image stack.
    Widget imageWidget = Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: recipeData!['photo'] != null && recipeData!['photo']['fileName'] != null
            ? CachedNetworkImage(
                imageUrl: '$apiUrl/images/${recipeData!['photo']['fileName']}',
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.error, size: 40),
                ),
              )
            : Container(
                color: Colors.grey[300],
                child: const Icon(Icons.no_food, size: 40),
              ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipeData!['name'] ?? 'Unnamed Recipe',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipeData!['category'] ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey[200]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Add like button
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              // Like button
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: InkWell(
                  onTap: _updateLikeCount,
                  child: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red.shade400 : Colors.white,
                    size: 24,
                  ),
                ),
              ),
              // Like count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_likeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Share button
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: InkWell(
                  onTap: _shareRecipe,
                  child: const Icon(
                    Icons.share,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Preparation time badge
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  '$prepTime min',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Private recipe indicator
        if (isPrivate)
          Positioned(
            top: 56, // Below prep time
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  const Text(
                    'Private',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    // If on a larger screen, wrap the image in a centered container at 50% width.
    Widget imageSection = isLargeScreen
        ? Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.5,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
              ),
              child: imageWidget,
            ),
          )
        : imageWidget;

    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.black.withOpacity(0.5),
          onPressed: () => Navigator.pop(context, _likeStatusChanged),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Use the updated image section
                  Container(
                    color: Colors.green.shade50,
                    child: imageSection,
                  ),

                  Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Nutritional Information Row using localized labels

                          // Portion Control widget
                          Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Text(
                                    'Portion Size',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Adjust to scale recipe ingredients and nutrition',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Decrease button
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle),
                                        color: Theme.of(context).primaryColor,
                                        onPressed: _decreasePortion,
                                        tooltip: 'Decrease portion',
                                      ),
                                      // Portion multiplier display
                                      Container(
                                        width: 80,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${_portionMultiplier.toStringAsFixed(1)}x',
                                          style: Theme.of(context).textTheme.titleMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      // Increase button
                                      IconButton(
                                        icon: const Icon(Icons.add_circle),
                                        color: Theme.of(context).primaryColor,
                                        onPressed: _increasePortion,
                                        tooltip: 'Increase portion',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Author text
                          if (authorText.isNotEmpty)
                            Text(
                              authorText,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                          if (authorText.isNotEmpty)
                            const SizedBox(height: 8),

                          // Full Recipe Description
                          Text(
                            recipeData!['description'] ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildNutrientColumn(
                                  loc.calories,
                                  Icons.local_fire_department,
                                  'kcal',
                                  (recipeData!['kcalPortion'] ?? 0) * _portionMultiplier,
                                  Colors.redAccent),
                              _buildNutrientColumn(
                                  loc.protein,
                                  Icons.scale,
                                  'g',
                                  (recipeData!['proteinPortion'] ?? 0) * _portionMultiplier,
                                  Colors.blue),
                              _buildNutrientColumn(
                                  loc.carbs,
                                  Icons.grain,
                                  'g',
                                  (recipeData!['carbohydratesPortion'] ?? 0) * _portionMultiplier,
                                  Colors.orange),
                              _buildNutrientColumn(
                                  loc.fat,
                                  Icons.opacity,
                                  'g',
                                  (recipeData!['fatContentPortion'] ?? 0) * _portionMultiplier,
                                  Colors.purple),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Ingredients Section using localized title
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showIngredients = !_showIngredients;
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  loc.ingredients,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                IconButton(
                                  icon: Icon(_showIngredients 
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    setState(() {
                                      _showIngredients = !_showIngredients;
                                    });
                                  },
                                  tooltip: _showIngredients 
                                    ? 'Hide ingredients' 
                                    : 'Show ingredients',
                                ),
                              ],
                            ),
                          ),
                          
                          // Using AnimatedCrossFade for smooth transitions
                          AnimatedCrossFade(
                            crossFadeState: _showIngredients 
                              ? CrossFadeState.showFirst 
                              : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 300),
                            firstChild: Padding(
                              padding: const EdgeInsets.only(top: 0),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: recipeData!['ingredients']?.length ?? 0,
                                separatorBuilder: (context, index) =>
                                    const Divider(),
                                itemBuilder: (context, index) {
                                  final ingredient =
                                      recipeData!['ingredients'][index];
                                  final product = ingredient['productId'];
                                  final quantity = ingredient['quantity'] ?? 0;
                                  
                                  // Apply portion multiplier to the original quantity
                                  final adjustedQuantity = quantity * _portionMultiplier;
                                  
                                  // Calculate nutrition values based on adjusted quantity
                                  final calculatedKcal = calculateNutrition(
                                    product?['kcalPortion']?.toDouble(), quantity);
                                  final calculatedProtein = calculateNutrition(
                                    product?['proteinPortion']?.toDouble(), quantity);
                                  final calculatedCarbs = calculateNutrition(
                                    product?['carbohydratesPortion']?.toDouble(), quantity);
                                  final calculatedFat = calculateNutrition(
                                    product?['fatContentPortion']?.toDouble(), quantity);
                                  
                                  return ExpansionTile(
                                    tilePadding: EdgeInsets.symmetric(horizontal: 8.0),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: product != null && product['photo'] != null
                                        ? CachedNetworkImage(
                                            imageUrl: '$apiUrl/images/${product['photo']['fileName']}',
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              width: 50,
                                              height: 50,
                                              color: Colors.grey[300],
                                              child: const Center(child: CircularProgressIndicator()),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              width: 50,
                                              height: 50,
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.error, size: 24),
                                            ),
                                          )
                                        : Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.food_bank, size: 24),
                                          ),
                                    ),
                                    title: Text(product != null ? product['name'] ?? 'Unknown Item' : 'Unknown Item'),
                                    subtitle: Text(
                                      '${adjustedQuantity.toStringAsFixed(1)} g',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Nutritional values for ${adjustedQuantity.toStringAsFixed(1)}g:',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                                              children: [
                                                _buildIngredientNutrition(
                                                  'Calories', 
                                                  '${calculatedKcal.toStringAsFixed(1)} kcal',
                                                  Colors.redAccent
                                                ),
                                                _buildIngredientNutrition(
                                                  'Protein', 
                                                  '${calculatedProtein.toStringAsFixed(1)} g',
                                                  Colors.blue
                                                ),
                                                _buildIngredientNutrition(
                                                  'Carbs', 
                                                  '${calculatedCarbs.toStringAsFixed(1)} g',
                                                  Colors.orange
                                                ),
                                                _buildIngredientNutrition(
                                                  'Fat', 
                                                  '${calculatedFat.toStringAsFixed(1)} g',
                                                  Colors.purple
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text('Per 100g:',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                                              children: [
                                                _buildIngredientNutrition(
                                                  'Calories', 
                                                  '${product?['kcalPortion'] ?? 0} kcal',
                                                  Colors.redAccent
                                                ),
                                                _buildIngredientNutrition(
                                                  'Protein', 
                                                  '${product?['proteinPortion'] ?? 0} g',
                                                  Colors.blue
                                                ),
                                                _buildIngredientNutrition(
                                                  'Carbs', 
                                                  '${product?['carbohydratesPortion'] ?? 0} g',
                                                  Colors.orange
                                                ),
                                                _buildIngredientNutrition(
                                                  'Fat', 
                                                  '${product?['fatContentPortion'] ?? 0} g',
                                                  Colors.purple
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            secondChild: SizedBox(height: 0),
                          ),
                          const SizedBox(height: 16),

                          // Preparation Section using localized title
                          Text(
                            loc.preparation,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            recipeData!['preparation'] ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 32),
                          
                          // Print button at bottom
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: () => print('Printing'),
                              icon: const Icon(Icons.print),
                              label: const Text('Print Recipe'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _buildNutrientColumn(
    String label, IconData icon, String unit, dynamic value, Color color) {
  // Convert value to double first, then format it, defaulting to 0 if null or invalid
  final double numValue = value is int ? value.toDouble() : 
                           value is double ? value : 0.0;
  
  // Format to one decimal place if it's not a whole number
  final String displayValue = numValue == numValue.roundToDouble() 
      ? numValue.round().toString() 
      : numValue.toStringAsFixed(1);
  
  return Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 4),
      Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text('$displayValue $unit', style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    ],
  );
}

// Helper method for ingredient nutrition display
Widget _buildIngredientNutrition(String label, String value, Color color) {
  return Column(
    children: [
      Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 12)),
    ],
  );
}
