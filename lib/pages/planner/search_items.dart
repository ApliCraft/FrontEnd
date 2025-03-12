import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/api/recipe.dart';
import 'package:decideat/api/product.dart';
import 'package:decideat/api/api.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchItemsPage extends StatefulWidget {
  final String mealType; // 'Breakfast', 'Lunch', 'Dinner', 'Snack', 'All'
  final DateTime selectedDate;

  const SearchItemsPage({
    Key? key,
    required this.mealType,
    required this.selectedDate,
  }) : super(key: key);

  @override
  _SearchItemsPageState createState() => _SearchItemsPageState();
}

class _SearchItemsPageState extends State<SearchItemsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  List<Recipe> _recipes = [];
  List<Product> _products = [];
  bool _isLoadingRecipes = true;
  bool _isLoadingProducts = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecipes();
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoadingRecipes = true;
      _errorMessage = null;
    });

    try {
      // Convert meal type to category for API
      final categoryMap = {
        'Breakfast': 'Breakfast',
        'Lunch': 'Lunch',
        'Dinner': 'Dinner',
        'Snack': 'Snack',
      };

      String category = categoryMap[widget.mealType] ?? '';
      
      final idsResponse = await http.post(
        Uri.parse('$apiUrl/recipe/get-ids-by-params'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'category': category.isEmpty ? null : category,
        }),
      );

      if (idsResponse.statusCode == 200) {
        final List<dynamic> recipesData = json.decode(idsResponse.body);
        List<Recipe> fetchedRecipes = [];

        // Fetch recipe details in parallel (up to 10 at a time to avoid overwhelming the API)
        const batchSize = 10;
        for (int i = 0; i < recipesData.length; i += batchSize) {
          final currentBatch = recipesData.skip(i).take(batchSize).toList();
          
          final futures = currentBatch.map((recipeData) async {
            if (recipeData != null && recipeData.containsKey('_id')) {
              final String recipeId = recipeData['_id'];
              try {
                final recipeResponse = await http.get(
                  Uri.parse('$apiUrl/recipe/$recipeId'),
                  headers: {'Content-Type': 'application/json'},
                );
                
                if (recipeResponse.statusCode == 200) {
                  final recipeFullData = json.decode(recipeResponse.body);
                  return Recipe.fromJson(recipeFullData);
                }
              } catch (e) {
                print('Error fetching recipe $recipeId: $e');
              }
            }
            return null;
          }).toList();

          final results = await Future.wait(futures);
          fetchedRecipes.addAll(results.whereType<Recipe>().toList());
        }
        
        setState(() {
          _recipes = fetchedRecipes;
          _isLoadingRecipes = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load recipes: ${idsResponse.statusCode}';
          _isLoadingRecipes = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading recipes: $e';
        _isLoadingRecipes = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      // Map meal type to likely product categories
      final categoryMap = {
        'Breakfast': ['Dairy', 'Cereal products', 'Fruits'],
        'Lunch': ['Meat', 'Vegetables', 'Fish and Seafood'],
        'Dinner': ['Meat', 'Vegetables', 'Fish and Seafood'],
        'Snack': ['Fruits', 'Nuts', 'Sweets and Snacks'],
      };

      List<String> relevantCategories = categoryMap[widget.mealType] ?? [];
      List<Product> allProducts = [];
      
      if (relevantCategories.isEmpty) {
        // Load all product categories if no specific categories for this meal type
        relevantCategories = [
          'Fruits',
          'Vegetables',
          'Cereal products',
          'Dairy',
          'Fish and Seafood',
          'Fluids',
          'Meat',
          'Nuts',
          'Sweets and Snacks'
        ];
      }
      
      // Load products for each relevant category
      for (final category in relevantCategories) {
        try {
          final response = await http.post(
            Uri.parse('$apiUrl/product/filter'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "class": category,
            }),
          );
          
          if (response.statusCode == 200) {
            final List<dynamic> data = json.decode(response.body);
            final products = data.map((json) => Product.fromJson(json)).toList();
            allProducts.addAll(products);
          }
        } catch (e) {
          print('Error fetching $category products: $e');
        }
      }
      
      setState(() {
        _products = allProducts;
        _isLoadingProducts = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading products: $e';
        _isLoadingProducts = false;
      });
    }
  }

  List<Recipe> get _filteredRecipes {
    if (_searchQuery.isEmpty) return _recipes;
    return _recipes.where((recipe) => 
      recipe.recipeName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (recipe.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((product) => 
      product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (product.plName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.mealType} - Add Item'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Recipes'),
            Tab(text: 'Products'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search recipes and products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Error message if any
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Recipes tab
                _isLoadingRecipes 
                  ? const Center(child: CircularProgressIndicator())
                  : _buildRecipesList(),
                
                // Products tab
                _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _buildProductsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipesList() {
    final recipes = _filteredRecipes;
    
    if (recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty 
                  ? 'No recipes available for ${widget.mealType}'
                  : 'No recipes matching "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _loadRecipes,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          child: InkWell(
            onTap: () async {
              // Create a map with all the recipe details
              final recipeDetails = {
                'type': 'recipe',
                'id': recipe.id,
                '_id': recipe.id, // Add both formats to ensure compatibility
                'name': recipe.recipeName,
                'calories': recipe.kcalPortion,
                'protein': recipe.proteinPortion,
                'carbs': recipe.carbohydratesPortion,
                'fat': recipe.fatContentPortion,
                'photo': recipe.photo,
                'category': recipe.category,
                'description': recipe.description ?? '',
                'prepTime': recipe.prepareTime,
              };
              
              // Log recipe details for debugging
              print('Recipe details before dialog: $recipeDetails');
              
              // Show portion dialog before returning result
              final result = await _showRecipePortionDialog(recipeDetails);
              if (result != null) {
                Navigator.pop(context, result);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Recipe image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 80,
                      height: 80,
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
                              );
                            }
                          }
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.restaurant, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Recipe details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.recipeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (recipe.description != null && recipe.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            recipe.description!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Nutrition info
                        Wrap(
                          spacing: 12,
                          children: [
                            _buildNutritionTag(
                              icon: Icons.local_fire_department,
                              value: '${recipe.kcalPortion} kcal',
                              color: Colors.orange.shade700,
                            ),
                            _buildNutritionTag(
                              icon: Icons.timer,
                              value: '${recipe.prepareTime} min',
                              color: Colors.blue.shade600,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Add icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsList() {
    final products = _filteredProducts;
    
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty 
                  ? 'No products available for ${widget.mealType}'
                  : 'No products matching "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _loadProducts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          child: InkWell(
            onTap: () async {
              // Create a map with all the product details
              final productDetails = {
                'type': 'product',
                'id': product.id,
                '_id': product.id, // Add both formats to ensure compatibility
                'name': product.name,
                'calories': product.kcalPortion,
                'protein': product.proteinPortion,
                'carbs': product.carbohydratesPortion,
                'fat': product.fatContentPortion,
                'photo': product.imageUrl,
                'category': product.category,
              };
              
              // Log product details for debugging
              print('Product details before dialog: $productDetails');
              
              // Show portion dialog before returning result
              final result = await _showProductPortionDialog(productDetails);
              if (result != null) {
                Navigator.pop(context, result);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Product image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: product.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrl.startsWith('http')
                                ? product.imageUrl
                                : '$apiUrl/images/${product.imageUrl}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.fastfood, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.fastfood, color: Colors.grey),
                          ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Product details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (product.plName != null && product.plName!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            product.plName!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          children: [
                            _buildNutritionTag(
                              icon: Icons.local_fire_department,
                              value: '${product.kcalPortion} kcal',
                              color: Colors.orange.shade700,
                            ),
                            _buildNutritionTag(
                              icon: Icons.category,
                              value: product.category,
                              color: Colors.teal.shade600,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Add icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNutritionTag({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showRecipePortionDialog(Map<String, dynamic> recipe) async {
    TimeOfDay selectedTime = TimeOfDay.now();
    double portion = 1.0; // Default portion multiplier
    
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Calculate nutritional values based on portion size
            final calories = (recipe['calories'] as num).toDouble();
            final protein = (recipe['protein'] as num).toDouble();
            final carbs = (recipe['carbs'] as num).toDouble();
            final fat = (recipe['fat'] as num).toDouble();
            
            // Debug log for initial values
            print('Recipe dialog - Initial portion: $portion');
            
            return AlertDialog(
              title: Text('Set Meal Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Recipe image if available
                    if (recipe['photo'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 120,
                          height: 80,
                          child: StreamBuilder<FileResponse>(
                            stream: DefaultCacheManager().getFileStream(
                              '$apiUrl/images/${recipe['photo']['fileName']}',
                              withProgress: true,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data is FileInfo) {
                                return Image.file(
                                  (snapshot.data as FileInfo).file,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(
                                color: Colors.grey.shade200,
                                child: Icon(Icons.restaurant, color: Colors.grey.shade400),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Recipe name
                    Text(
                      recipe['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Time selector
                    ListTile(
                      title: Text('Time'),
                      trailing: Text(_formatTimeIn24Hour(selectedTime)),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                          builder: (context, child) {
                            return MediaQuery(
                              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => selectedTime = picked);
                        }
                      },
                    ),
                    
                    // Portion size selector with finer control (0.1x increments)
                    ListTile(
                      title: Text('Portion Size'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove),
                            onPressed: () {
                              if (portion > 0.1) {
                                setState(() {
                                  portion = (portion - 0.1);
                                  // Round to 1 decimal place for clean display
                                  portion = double.parse(portion.toStringAsFixed(1));
                                  print('Recipe dialog - Decreased portion: $portion');
                                });
                              }
                            },
                          ),
                          Text('${portion}x'),
                          IconButton(
                            icon: Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                portion = (portion + 0.1);
                                // Round to 1 decimal place for clean display
                                portion = double.parse(portion.toStringAsFixed(1));
                                print('Recipe dialog - Increased portion: $portion');
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Nutritional info based on portion
                    const Divider(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nutritional Info (with selected portion):',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildNutrientRow(
                            Icons.local_fire_department, 
                            'Calories', 
                            '${(calories * portion).round()} kcal',
                            Colors.orange.shade700
                          ),
                          _buildNutrientRow(
                            Icons.fitness_center, 
                            'Protein', 
                            '${(protein * portion).round()} g',
                            Colors.purple
                          ),
                          _buildNutrientRow(
                            Icons.grain, 
                            'Carbs', 
                            '${(carbs * portion).round()} g',
                            Colors.amber.shade700
                          ),
                          _buildNutrientRow(
                            Icons.opacity, 
                            'Fat', 
                            '${(fat * portion).round()} g',
                            Colors.blue
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final formattedTime = _formatTimeIn24Hour(selectedTime);
                    
                    // Ensure portion is a valid double and at least 0.1 to avoid 0.0 servings
                    final double finalPortion = (portion <= 0.0) ? 1.0 : portion;
                    print('Recipe dialog - Final portion value: $finalPortion (${finalPortion.runtimeType})');
                    
                    // Create a new map for the result to avoid any reference issues
                    final Map<String, dynamic> result = {
                      'type': 'recipe',
                      'id': recipe['id'],
                      '_id': recipe['id'],
                      'name': recipe['name'],
                      'time': formattedTime,
                      'servings': finalPortion,
                      'portion': finalPortion,
                      'calories': (calories * finalPortion),
                      'protein': (protein * finalPortion),
                      'carbs': (carbs * finalPortion),
                      'fat': (fat * finalPortion),
                    };
                    
                    // Log the final result for debugging
                    print('Final recipe result: $result');
                    
                    Navigator.pop(context, result);
                  },
                  child: Text('Add to Plan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _showProductPortionDialog(Map<String, dynamic> product) async {
    TimeOfDay selectedTime = TimeOfDay.now();
    TextEditingController gramController = TextEditingController(text: '100');
    int grams = 100;
    
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Calculate nutritional values based on grams
            final calories = (product['calories'] as num).toDouble();
            final protein = (product['protein'] as num).toDouble();
            final carbs = (product['carbs'] as num).toDouble();
            final fat = (product['fat'] as num).toDouble();
            
            double multiplier = grams / 100.0;
            int calculatedCalories = (calories * multiplier).round();
            int calculatedProtein = (protein * multiplier).round();
            int calculatedCarbs = (carbs * multiplier).round();
            int calculatedFat = (fat * multiplier).round();

            return AlertDialog(
              title: Text('Set Product Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product image if available
                    if (product['photo'] != null && product['photo'].toString().isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 120,
                          height: 80,
                          child: CachedNetworkImage(
                            imageUrl: product['photo'].startsWith('http')
                                ? product['photo'] 
                                : '$apiUrl/images/${product['photo']}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.fastfood, color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Product name
                    Text(
                      product['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Time selector
                    ListTile(
                      title: Text('Time'),
                      trailing: Text(_formatTimeIn24Hour(selectedTime)),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                          builder: (context, child) {
                            return MediaQuery(
                              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => selectedTime = picked);
                        }
                      },
                    ),
                    
                    // Portion size in grams
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextField(
                        controller: gramController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Portion Size',
                          suffixText: 'g',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            grams = int.tryParse(value) ?? 100;
                          });
                        },
                      ),
                    ),
                    
                    // Nutritional details
                    const Divider(height: 16),
                    
                    // Per 100g values
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Per 100g:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildNutrientRow(
                            Icons.local_fire_department, 
                            'Calories', 
                            '${calories.round()} kcal',
                            Colors.orange.shade700
                          ),
                          _buildNutrientRow(
                            Icons.fitness_center, 
                            'Protein', 
                            '${protein.round()} g',
                            Colors.purple
                          ),
                          _buildNutrientRow(
                            Icons.grain, 
                            'Carbs', 
                            '${carbs.round()} g',
                            Colors.amber.shade700
                          ),
                          _buildNutrientRow(
                            Icons.opacity, 
                            'Fat', 
                            '${fat.round()} g',
                            Colors.blue
                          ),
                        ],
                      ),
                    ),
                    
                    const Divider(height: 16),
                    
                    // Selected portion values
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected portion ($grams g):',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildNutrientRow(
                            Icons.local_fire_department, 
                            'Calories', 
                            '$calculatedCalories kcal',
                            Colors.orange.shade700
                          ),
                          _buildNutrientRow(
                            Icons.fitness_center, 
                            'Protein', 
                            '$calculatedProtein g',
                            Colors.purple
                          ),
                          _buildNutrientRow(
                            Icons.grain, 
                            'Carbs', 
                            '$calculatedCarbs g',
                            Colors.amber.shade700
                          ),
                          _buildNutrientRow(
                            Icons.opacity, 
                            'Fat', 
                            '$calculatedFat g',
                            Colors.blue
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final formattedTime = _formatTimeIn24Hour(selectedTime);
                    final result = {
                      ...product,
                      'time': formattedTime,
                      'amount': grams.toDouble(),
                      'portion': grams.toDouble(),
                      'type': 'product',
                      'id': product['id'],
                      '_id': product['id'],
                      'calories': calculatedCalories.toDouble(),
                      'protein': calculatedProtein.toDouble(),
                      'carbs': calculatedCarbs.toDouble(),
                      'fat': calculatedFat.toDouble(),
                    };
                    
                    // Log the final result for debugging
                    print('Final product result: $result');
                    
                    Navigator.pop(context, result);
                  },
                  child: Text('Add to Plan'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  Widget _buildNutrientRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to format time in 24-hour format
  String _formatTimeIn24Hour(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}