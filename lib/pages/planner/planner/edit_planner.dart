import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:decideat/pages/planner.dart';
import 'package:decideat/pages/planner/example_search.dart';
import 'package:decideat/pages/planner/search_items.dart';
import 'package:decideat/api/planner.dart';
import 'package:decideat/api/api.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';

class MealItem {
  final String id;
  final String name;
  final String time;
  final String type; // 'recipe' or 'product'
  final String category;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final dynamic photo;
  final dynamic portionInfo; // New field to store portion info
  bool isCompleted;

  MealItem({
    required this.id,
    required this.name,
    required this.time,
    required this.type,
    required this.category,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.photo,
    this.portionInfo,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'time': time,
      'type': type,
      'category': category,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'photo': photo,
      'portionInfo': portionInfo,
      'isCompleted': isCompleted,
    };
  }

  factory MealItem.fromMap(Map<String, dynamic> map) {
    return MealItem(
      id: map['id'],
      name: map['name'],
      time: map['time'],
      type: map['type'],
      category: map['category'],
      calories: map['calories'] is int ? (map['calories'] as int).toDouble() : map['calories'],
      protein: map['protein'] is int ? (map['protein'] as int).toDouble() : map['protein'],
      carbs: map['carbs'] is int ? (map['carbs'] as int).toDouble() : map['carbs'],
      fat: map['fat'] is int ? (map['fat'] as int).toDouble() : map['fat'],
      photo: map['photo'],
      portionInfo: map['portionInfo'],
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class EditPlannerPage extends StatefulWidget {
  final DateTime selectedDate;
  const EditPlannerPage({Key? key, required this.selectedDate})
      : super(key: key);

  @override
  _EditPlannerPageState createState() => _EditPlannerPageState();
}

class _EditPlannerPageState extends State<EditPlannerPage> {
  List<MealItem> mealItems = [];
  bool _isLoading = false; // Add loading state
  
  // Default meal times
  final Map<String, String> defaultMealTimes = {
    'Breakfast': '08:00',
    'Lunch': '12:30',
    'Dinner': '19:00',
    'Snack': '16:00',
  };

  @override
  void initState() {
    super.initState();
    _loadMealItems(); // Load real data instead of sample data
  }

  Future<void> _loadMealItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the API to load meal data
      final dateString = widget.selectedDate.toIso8601String();
      final plannerData = await ApiServicePlanner.getMeals(dateString);
      
      List<MealItem> newMealItems = [];
      
      // Check if the planner data is valid and contains meals
      if (plannerData != null && 
          plannerData.planner != null && 
          plannerData.planner.meals != null && 
          plannerData.planner.meals.isNotEmpty) {
          
        for (var meal in plannerData.planner.meals) {
          // Process products
          if (meal.products != null) {
            for (var product in meal.products) {
              try {
                if (product.productId == null || product.productId.isEmpty) {
                  continue; // Skip invalid products
                }
                
                // Fetch product details
                final productDetails = await _fetchProductDetails(product.productId);
                
                if (productDetails == null) {
                  continue; // Skip if product details couldn't be fetched
                }
                
                final amount = product.amount;
                double calories = 0.0;
                double protein = 0.0;
                double carbs = 0.0;
                double fat = 0.0;
                
                // Safely parse nutritional values
                try {
                  // Directly access nutritional values from product details
                  // Using the same approach as in planner.dart
                  calories = double.parse(productDetails['kcalPortion']?.toString() ?? '0') * amount / 100;
                  protein = double.parse(productDetails['proteinPortion']?.toString() ?? '0') * amount / 100;
                  carbs = double.parse(productDetails['carbohydratesPortion']?.toString() ?? '0') * amount / 100;
                  fat = double.parse(productDetails['fatContentPortion']?.toString() ?? '0') * amount / 100;
                  
                  // Debug log
                  print('Product nutritional values for ${productDetails['name']}:');
                  print('Base values - kcal: ${productDetails['kcalPortion']}, protein: ${productDetails['proteinPortion']}, carbs: ${productDetails['carbohydratesPortion']}, fat: ${productDetails['fatContentPortion']}');
                  print('Amount: $amount g');
                  print('Final values - kcal: $calories, protein: $protein, carbs: $carbs, fat: $fat');
                } catch (e) {
                  print('Error parsing product nutritional values: $e');
                  // Print the exact error and stack trace for debugging
                  print('Error details: ${e.toString()}');
                }
                
                // Get photo URL
                String photoUrl = '';
                if (productDetails['photo'] != null && productDetails['photo']['fileName'] != null) {
                  photoUrl = '$apiUrl/images/${productDetails['photo']['fileName']}';
                }
                
                newMealItems.add(MealItem(
                  id: meal.id,
                  name: productDetails['name'] ?? 'Unknown Product',
                  time: meal.time,
                  type: 'product',
                  category: meal.category,
                  calories: calories,
                  protein: protein,
                  carbs: carbs,
                  fat: fat,
                  photo: photoUrl,
                  portionInfo: {'productId': product.productId, 'amount': amount},
                  isCompleted: meal.completed,
                ));
              } catch (e) {
                print('Error processing product: $e');
                // Continue to next product instead of stopping
              }
            }
          }
          
          // Process recipes
          if (meal.recipes != null) {
            for (var recipe in meal.recipes) {
              try {
                if (recipe.recipeId == null || recipe.recipeId.isEmpty) {
                  continue; // Skip invalid recipes
                }
                
                // Fetch recipe details
                final recipeDetails = await _fetchRecipeDetails(recipe.recipeId);
                
                if (recipeDetails == null) {
                  continue; // Skip if recipe details couldn't be fetched
                }
                
                final servings = recipe.servings;
                double baseServings = double.tryParse(recipeDetails['servings']?.toString() ?? '1') ?? 1;
                double servingMultiplier = servings / baseServings;
                
                // Calculate nutritional values based on servings
                double calories = 0.0;
                double protein = 0.0;
                double carbs = 0.0;
                double fat = 0.0;
                
                try {
                  // Directly access nutritional values from recipe details
                  // Using the same approach as in planner.dart
                  calories = double.parse(recipeDetails['kcalPortion']?.toString() ?? '0') * servings;
                  protein = double.parse(recipeDetails['proteinPortion']?.toString() ?? '0') * servings;
                  carbs = double.parse(recipeDetails['carbohydratesPortion']?.toString() ?? '0') * servings;
                  fat = double.parse(recipeDetails['fatContentPortion']?.toString() ?? '0') * servings;
                  
                  // Print debug info
                  print('Recipe nutritional values for ${recipeDetails['name']}:');
                  print('Base values - kcal: ${recipeDetails['kcalPortion']}, protein: ${recipeDetails['proteinPortion']}, carb: ${recipeDetails['carbohydratesPortion']}, fat: ${recipeDetails['fatContentPortion']}');
                  print('Servings: $servings, Base servings: $baseServings, Multiplier: $servingMultiplier');
                  print('Final values - kcal: $calories, protein: $protein, carb: $carbs, fat: $fat');
                } catch (e) {
                  print('Error parsing recipe nutritional values: $e');
                  print('Error details: ${e.toString()}');
                }
                
                // Get photo URL
                String photoUrl = '';
                if (recipeDetails['photo'] != null && recipeDetails['photo']['fileName'] != null) {
                  photoUrl = '$apiUrl/images/${recipeDetails['photo']['fileName']}';
                }
                
                newMealItems.add(MealItem(
                  id: meal.id,
                  name: recipeDetails['name'] ?? 'Unknown Recipe',
                  time: meal.time,
                  type: 'recipe',
                  category: meal.category,
                  calories: calories,
                  protein: protein,
                  carbs: carbs,
                  fat: fat,
                  photo: photoUrl,
                  portionInfo: {'recipeId': recipe.recipeId, 'servings': servings},
                  isCompleted: meal.completed,
                ));
              } catch (e) {
                print('Error processing recipe: $e');
                print('Full recipe object: ${recipe.toString()}');
                // Continue to next recipe instead of stopping
              }
            }
          }
        }
        
        // Sort meal items by completion status and time
        newMealItems.sort((a, b) {
          // First compare by completion status (uncompleted first)
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          
          // Then compare by time
          try {
            final timeA = _parseTime(a.time);
            final timeB = _parseTime(b.time);
            return timeA.compareTo(timeB);
          } catch (e) {
            return a.time.compareTo(b.time);
          }
        });
      }
      
      setState(() {
        mealItems = newMealItems;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading meal items: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }
  
  // Function to fetch product details
  Future<Map<String, dynamic>?> _fetchProductDetails(String productId) async {
    try {
      await RefreshTokenIfExpired();
      final accessToken = await storage.read(key: 'accessToken');
      
      print('Fetching product details for ID: $productId');
      final url = Uri.parse('$apiUrl/product/$productId');
      final response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Debug: Print complete product details
        print('========== PRODUCT DETAILS ==========');
        print('Product ID: $productId');
        print('Product name: ${data['name']}');
        print('Raw nutritional data:');
        print('  kcalPortion: ${data['kcalPortion']} (${data['kcalPortion']?.runtimeType})');
        print('  proteinPortion: ${data['proteinPortion']} (${data['proteinPortion']?.runtimeType})');
        print('  carbohydratesPortion: ${data['carbohydratesPortion']} (${data['carbohydratesPortion']?.runtimeType})');
        print('  fatContentPortion: ${data['fatContentPortion']} (${data['fatContentPortion']?.runtimeType})');
        print('====================================');
        
        return data;
      } else if (response.statusCode == 404) {
        print('Product not found: $productId');
        return null;
      } else {
        print('Failed to load product details: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null; // Return null instead of throwing exception
      }
    } catch (e) {
      print('Error fetching product details: $e');
      return null; // Return null instead of throwing exception
    }
  }
  
  // Function to fetch recipe details
  Future<Map<String, dynamic>?> _fetchRecipeDetails(String recipeId) async {
    try {
      await RefreshTokenIfExpired();
      final accessToken = await storage.read(key: 'accessToken');
      
      print('Fetching recipe details for ID: $recipeId');
      final url = Uri.parse('$apiUrl/recipe/$recipeId');
      final response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Debug: Print complete recipe details
        print('========== RECIPE DETAILS ==========');
        print('Recipe ID: $recipeId');
        print('Recipe name: ${data['name']}');
        print('Servings: ${data['servings']} (${data['servings']?.runtimeType})');
        
        // Check if nutritionalValue is present and print its structure
        if (data['nutritionalValue'] != null) {
          final nutritionalValue = data['nutritionalValue'];
          print('Raw nutritional data:');
          print('  calories: ${nutritionalValue['calories']} (${nutritionalValue['calories']?.runtimeType})');
          print('  protein: ${nutritionalValue['protein']} (${nutritionalValue['protein']?.runtimeType})');
          print('  carbohydrates: ${nutritionalValue['carbohydrates']} (${nutritionalValue['carbohydrates']?.runtimeType})');
          print('  fat: ${nutritionalValue['fat']} (${nutritionalValue['fat']?.runtimeType})');
        } else {
          print('WARNING: No nutritionalValue found in recipe data!');
          print('Available keys in recipe data: ${data.keys.toList()}');
        }
        print('====================================');
        
        return data;
      } else if (response.statusCode == 404) {
        print('Recipe not found: $recipeId');
        return null;
      } else {
        print('Failed to load recipe details: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null; // Return null instead of throwing exception
      }
    } catch (e) {
      print('Error fetching recipe details: $e');
      return null; // Return null instead of throwing exception
    }
  }

  // Helper function to parse nutritional values
  double _parseNutritionalValue(dynamic value) {
    if (value == null) return 0.0;
    
    // Handle numeric values
    if (value is num) return value.toDouble();
    
    // Handle string values, including those with commas or other formatting
    if (value is String) {
      // Replace commas with periods for locales that use commas as decimal separators
      String cleanValue = value.replaceAll(',', '.');
      
      // Remove any non-numeric characters except the decimal point
      cleanValue = cleanValue.replaceAll(RegExp(r'[^\d.]'), '');
      
      // Parse the clean string
      return double.tryParse(cleanValue) ?? 0.0;
    }
    
    // For any other type, return 0.0
    return 0.0;
  }

  void _deleteItem(int index) {
    final loc = AppLocalizations.of(context)!;
    final itemName = mealItems[index].name;
    
    // Store a copy of the item before removing it
    final removedItem = mealItems[index];
    
    setState(() {
      mealItems.removeAt(index);
    });
    
    // Call API to delete meal item
    _removeMeal(removedItem.id).then((_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${itemName} removed from plan'),
        ),
      );
    }).catchError((e) {
      // Re-add the item if deletion fails
            setState(() {
              mealItems.insert(index, removedItem);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove ${itemName}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }
  
  // Function to delete meal with API
  Future<void> _removeMeal(String mealId) async {
    try {
      setState(() {
        _isLoading = true;  // Show loading indicator
      });
      
      await ApiServicePlanner.removeMeal(mealId);
      
      setState(() {
        // Remove from local list
        mealItems.removeWhere((meal) => meal.id == mealId);
      });
      
      await _loadMealItems(); // Refresh from API
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Meal removed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error removing meal: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove meal: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;  // Hide loading indicator
      });
    }
  }

  Future<void> _addMealItem(String mealType) async {
    try {
      setState(() {
        _isLoading = true;  // Show loading indicator while adding meal
      });
      
      final loc = AppLocalizations.of(context)!;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchItemsPage(
            mealType: mealType,
            selectedDate: widget.selectedDate,
          ),
        ),
      );

      if (result != null) {
        // Debug log to see the exact structure of the returned data
        print('Search Result: ${result.toString()}');
        
        // Use the time returned from SearchItemsPage or default time based on meal type
        String timeStr = result['time'] ?? defaultMealTimes[mealType] ?? '12:00';
        
        // Check if it's a product or recipe
        bool isProduct = result['type'] == 'product';
        String itemId = result['id'] ?? '';
        
        // Debug log for item ID
        print('Item ID: $itemId, Type: ${result['type']}');
        
        // Get the appropriate portion value based on type
        double portion = 0.0;
        
        if (isProduct) {
          // For products, look for 'amount' first, then fall back to 'portion'
          var rawAmount = result['amount'] ?? result['portion'];
          print('Raw amount value: $rawAmount (${rawAmount?.runtimeType})');
          
          // Convert to double regardless of input type
          if (rawAmount is int) {
            portion = rawAmount.toDouble();
          } else if (rawAmount is double) {
            portion = rawAmount;
          } else if (rawAmount is String) {
            portion = double.tryParse(rawAmount) ?? 100.0;
          } else {
            portion = 100.0; // Default for products
          }
        } else {
          // For recipes, look for 'servings' first, then fall back to 'portion'
          var rawServings = result['servings'] ?? result['portion'];
          print('Raw servings value: $rawServings (${rawServings?.runtimeType})');
          
          // Convert to double regardless of input type
          if (rawServings is int) {
            portion = rawServings.toDouble();
          } else if (rawServings is double) {
            portion = rawServings;
          } else if (rawServings is String) {
            portion = double.tryParse(rawServings) ?? 1.0;
          } else {
            portion = 1.0; // Default for recipes
          }
        }
        
        // Ensure minimum valid portion - never allow 0.0
        if (portion <= 0.0) {
          portion = isProduct ? 100.0 : 1.0;
        }
        
        // Debug log for portion
        print('Final portion to be sent to API: $portion (${portion.runtimeType})');
        
        try {
          // Format the date and time
          List<String> timeParts = timeStr.split(':');
          int hour = int.parse(timeParts[0]);
          int minute = int.parse(timeParts[1]);
          
          final formattedDate = DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month,
            widget.selectedDate.day,
            hour,
            minute,
          ).toIso8601String();
          
          // Log the API parameters
          print('API call parameters: date=$formattedDate, type=${isProduct ? 'product' : 'recipe'}, id=$itemId, category=${mealType.toLowerCase()}, portion=$portion');
          
          // Call the API to add the meal
          final apiResponse = await ApiServicePlanner.addMeal(
            date: formattedDate,
            type: isProduct ? 'product' : 'recipe',
            id: itemId,
            category: mealType.toLowerCase(),
            portion: portion,
          );
          
          print('API response successful: $apiResponse');
          
          // Reload the meal items to show the new item
          await _loadMealItems();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${result['name']} added to $mealType')),
          );
        } catch (e) {
          print('Error adding meal: $e');
          print('Error details: ${e.toString()}');
          print('Error type: ${e.runtimeType}');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add item: $e'),
              backgroundColor: Colors.red,
            ),
          );
          
          // Still reload to ensure any items that did get added are shown
          _loadMealItems();
        }
      }
    } catch (outerError) {
      print('Unexpected error in _addMealItem: $outerError');
      print('Error type: ${outerError.runtimeType}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $outerError'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;  // Hide loading indicator
      });
    }
  }

  // Function to edit a meal item
  void _editMealItem(int index) {
    final meal = mealItems[index];
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Meal'),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _deleteItem(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final dateFormatter = DateFormat('EEEE, MMMM d');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          dateFormatter.format(widget.selectedDate),
          style: const TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green.shade50,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            // Summary card
            _buildDaySummaryCard(),

            // Meal list
            Expanded(
              child: mealItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No meals planned for this day',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Meal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _showAddMealBottomSheet(),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      bottom: 100,
                      top: 16,
                      left: 16,
                      right: 16,
                    ),
                    itemCount: mealItems.length,
                    itemBuilder: (context, index) {
                      return _buildMealItemCard(index);
                    },
                  ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMealBottomSheet,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add),
        label: const Text('Add Meal'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDaySummaryCard() {
    // Calculate totals using doubles
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;

    // Debug output for calculations
    print("==== Day Summary Calculations ====");
    
    for (var meal in mealItems) {
      // Include all meals in the calculations, not just incomplete ones
      totalCalories += meal.calories;
      totalProtein += meal.protein;
      totalCarbs += meal.carbs;
      totalFat += meal.fat;
      
      // Debug output for each meal
      print("Meal: ${meal.name} - kcal: ${meal.calories}, protein: ${meal.protein}, carbs: ${meal.carbs}, fat: ${meal.fat}");
    }
    
    // Debug output for totals
    print("Day Totals - kcal: $totalCalories, protein: $totalProtein, carbs: $totalCarbs, fat: $totalFat");
    print("==============================");

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Day Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${mealItems.length} meals',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientColumn(
                  'Calories',
                  Icons.local_fire_department,
                  'kcal',
                  totalCalories,
                  Colors.redAccent,
                ),
                _buildNutrientColumn(
                  'Protein',
                  Icons.fitness_center,
                  'g',
                  totalProtein,
                  Colors.purple,
                ),
                _buildNutrientColumn(
                  'Carbs',
                  Icons.grain,
                  'g',
                  totalCarbs,
                  Colors.amber.shade700,
                ),
                _buildNutrientColumn(
                  'Fat',
                  Icons.opacity,
                  'g',
                  totalFat,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientColumn(
    String label,
    IconData icon,
    String unit,
    double value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              '${_formatNutritionalValue(value)} $unit',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMealItemCard(int index) {
    final meal = mealItems[index];
    
    final mealTypeColors = {
      'Breakfast': Colors.amber.shade700,
      'Lunch': Colors.green.shade700,
      'Dinner': Colors.blue.shade700,
      'Snack': Colors.purple.shade700,
    };
    
    final mealTypeIcons = {
      'Breakfast': Icons.free_breakfast,
      'Lunch': Icons.lunch_dining,
      'Dinner': Icons.dinner_dining,
      'Snack': Icons.cookie,
    };
    
    final color = mealTypeColors[meal.category] ?? Colors.grey;
    final icon = mealTypeIcons[meal.category] ?? Icons.restaurant;
    
    // Format portion info text
    String portionText = '';
    double portionMultiplier = 1.0;
    String itemId = '';
    
    if (meal.portionInfo != null) {
      if (meal.type == 'recipe') {
        // Extract servings value and recipeId from the portionInfo object
        final servings = meal.portionInfo['servings'] ?? 1.0;
        itemId = meal.portionInfo['recipeId'] ?? '';
        portionText = '$servings serving${servings > 1 ? 's' : ''}';
        portionMultiplier = servings;
      } else if (meal.type == 'product') {
        // Extract amount value from the portionInfo object
        final amount = meal.portionInfo['amount'] ?? 0.0;
        itemId = meal.portionInfo['productId'] ?? '';
        portionText = '${amount}g';
        portionMultiplier = amount / 100.0; // Convert to base unit multiplier
      }
    }
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time badge
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(icon, color: color),
                          const SizedBox(height: 4),
                          Text(
                            meal.time,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (meal.type == 'product') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          portionText,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(width: 16),
                
                // Meal details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${meal.category} · ${meal.type == 'recipe' ? 'Recipe' : 'Product'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (portionText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        // More prominent portion display
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: color.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                meal.type == 'recipe' ? Icons.restaurant : Icons.balance,
                                size: 14,
                                color: color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                portionText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Menu button
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _editMealItem(index),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            // Nutrition info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientInfo(
                  Icons.local_fire_department,
                  '${_formatNutritionalValue(meal.calories)}',
                  'kcal',
                  Colors.deepOrange,
                ),
                _buildNutrientInfo(
                  Icons.fitness_center,
                  '${_formatNutritionalValue(meal.protein)}',
                  'g protein',
                  Colors.purple,
                ),
                _buildNutrientInfo(
                  Icons.grain,
                  '${_formatNutritionalValue(meal.carbs)}',
                  'g carbs',
                  Colors.amber.shade700,
                ),
                _buildNutrientInfo(
                  Icons.opacity,
                  '${_formatNutritionalValue(meal.fat)}',
                  'g fat',
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientInfo(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  void _showAddMealBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: const Text(
                        'Add Meal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              _buildMealTypeButton(
                context,
                icon: Icons.free_breakfast,
                title: 'Breakfast',
                subtitle: 'Morning meal',
                color: Colors.amber.shade700,
                onTap: () {
                  Navigator.pop(context);
                  _addMealItem('Breakfast');
                },
              ),
              const Divider(height: 1, indent: 70),
              _buildMealTypeButton(
                context,
                icon: Icons.lunch_dining,
                title: 'Lunch',
                subtitle: 'Midday meal',
                color: Colors.green.shade700,
                onTap: () {
                  Navigator.pop(context);
                  _addMealItem('Lunch');
                },
              ),
              const Divider(height: 1, indent: 70),
              _buildMealTypeButton(
                context,
                icon: Icons.dinner_dining,
                title: 'Dinner',
                subtitle: 'Evening meal',
                color: Colors.blue.shade700,
                onTap: () {
                  Navigator.pop(context);
                  _addMealItem('Dinner');
                },
              ),
              const Divider(height: 1, indent: 70),
              _buildMealTypeButton(
                context,
                icon: Icons.cookie,
                title: 'Snack',
                subtitle: 'Between-meal refreshment',
                color: Colors.purple.shade700,
                onTap: () {
                  Navigator.pop(context);
                  _addMealItem('Snack');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMealTypeButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // Helper to format nutritional values for display with appropriate rounding
  String _formatNutritionalValue(double value) {
    // Round to 1 decimal place for cleaner display
    if (value < 10) {
      // For small values, show 1 decimal place
      return value.toStringAsFixed(1);
    } else {
      // For larger values, round to whole number for cleaner display
      return value.round().toString();
    }
  }
}
