import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/navigationPlannerAppBar.dart';
import '../widgets/bottomNavBar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/pages/planner/planner/edit_planner.dart';
import 'package:decideat/pages/planner/fluid_list.dart';
import '../api/planner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api/api.dart';
import 'package:decideat/pages/recipes/recipe.dart' as recipe_page;
import 'package:cached_network_image/cached_network_image.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({Key? key}) : super(key: key);

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  DateTime selectedDate = DateTime.now();
  double fluidIntake = 1.0; // in liters
  List<Map<String, dynamic>> scheduledRecipes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadScheduledMeals();
  }

  // Function to fetch product details
  Future<Map<String, dynamic>> _fetchProductDetails(String productId) async {
    await RefreshTokenIfExpired();
    final accessToken = await storage.read(key: 'accessToken');
    
    final url = Uri.parse('$apiUrl/product/$productId');
    final response = await http.get(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load product details');
    }
  }
  
  // Function to fetch recipe details
  Future<Map<String, dynamic>> _fetchRecipeDetails(String recipeId) async {
    await RefreshTokenIfExpired();
    final accessToken = await storage.read(key: 'accessToken');
    
    final url = Uri.parse('$apiUrl/recipe/$recipeId');
    final response = await http.get(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load recipe details');
    }
  }

  Future<void> _loadScheduledMeals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the API service to get data
      final dateString = selectedDate.toIso8601String();
      final plannerData = await ApiServicePlanner.getMeals(dateString);
      
      // Transform the data to match the expected format
      List<Map<String, dynamic>> recipes = [];
      
      if (plannerData != null && plannerData.planner.meals.isNotEmpty) {
        for (var meal in plannerData.planner.meals) {
          // For each product in the meal
          for (var product in meal.products) {
            try {
              // Fetch product details
              final productDetails = await _fetchProductDetails(product.productId);
              
              // Calculate nutritional values based on portion
              final amount = product.amount;
              final calories = double.parse(productDetails['kcalPortion'].toString()) * amount / 100;
              final protein = double.parse(productDetails['proteinPortion'].toString()) * amount / 100;
              final carbs = double.parse(productDetails['carbohydratesPortion'].toString()) * amount / 100;
              final fat = double.parse(productDetails['fatContentPortion'].toString()) * amount / 100;
              
              // Get photo URL
              String photoUrl = '';
              if (productDetails['photo'] != null && productDetails['photo']['filePath'] != null) {
                photoUrl = '$apiUrl/images/${productDetails['photo']['fileName']}';
              }
              
              recipes.add({
                '_id': meal.id,
                'name': productDetails['name'] ?? 'Unknown Product',
                'photo': photoUrl,
                'time': meal.time,
                'category': meal.category,
                'calories': calories,
                'protein': protein,
                'carbs': carbs,
                'fat': fat,
                'date': selectedDate,
                'completed': meal.completed,
                'productId': product.productId,
                'portion': amount,
                'isProduct': true,
              });
            } catch (e) {
              print('Error fetching product details: $e');
              // Add with default values if fetch fails
              recipes.add({
                '_id': meal.id,
                'name': 'Product ${product.productId}',
                'photo': '',
                'time': meal.time,
                'category': meal.category,
                'calories': 0.0,
                'protein': 0.0,
                'carbs': 0.0,
                'fat': 0.0,
                'date': selectedDate,
                'completed': meal.completed,
                'productId': product.productId,
                'portion': product.amount,
                'isProduct': true,
              });
            }
          }
          
          // For each recipe in the meal
          for (var recipe in meal.recipes) {
            try {
              // Fetch recipe details
              final recipeDetails = await _fetchRecipeDetails(recipe.recipeId);
              
              // Calculate nutritional values based on portion
              final servings = recipe.servings;
              final calories = double.parse(recipeDetails['kcalPortion'].toString()) * servings;
              final protein = double.parse(recipeDetails['proteinPortion'].toString()) * servings;
              final carbs = double.parse(recipeDetails['carbohydratesPortion'].toString()) * servings;
              final fat = double.parse(recipeDetails['fatContentPortion'].toString()) * servings;
              
              // Get photo URL
              String photoUrl = '';
              if (recipeDetails['photo'] != null && recipeDetails['photo']['filePath'] != null) {
                photoUrl = '$apiUrl/images/${recipeDetails['photo']['fileName']}';
              }
              
              recipes.add({
                '_id': meal.id,
                'name': recipeDetails['name'] ?? 'Unknown Recipe',
                'photo': photoUrl,
                'time': meal.time,
                'category': meal.category,
                'calories': calories,
                'protein': protein,
                'carbs': carbs,
                'fat': fat,
                'date': selectedDate,
                'completed': meal.completed,
                'recipeId': recipe.recipeId,
                'servings': recipe.servings,
                'isProduct': false,
              });
            } catch (e) {
              print('Error fetching recipe details: $e');
              // Add with default values if fetch fails
              recipes.add({
                '_id': meal.id,
                'name': 'Recipe ${recipe.recipeId}',
                'photo': '',
                'time': meal.time,
                'category': meal.category,
                'calories': 0.0,
                'protein': 0.0,
                'carbs': 0.0,
                'fat': 0.0,
                'date': selectedDate,
                'completed': meal.completed,
                'recipeId': recipe.recipeId,
                'servings': recipe.servings,
                'isProduct': false,
              });
            }
          }
        }
      }
      
      // Get nutritional summary for the day
      final nutritionalSummary = await ApiServicePlanner.getDailyNutritionalSummary(dateString);
      
      // Update the fluid intake if available from API
      if (plannerData != null) {
        fluidIntake = plannerData.fluidIntakeAmount / 1000.0; // Convert ml to liters
      }
      
      setState(() {
        scheduledRecipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading meals: $e')),
        );
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickDate() async {
    final currentLocale = Localizations.localeOf(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: currentLocale,
    );
    if (picked != null && !_isSameDay(picked, selectedDate)) {
      setState(() {
        selectedDate = picked;
      });
      _loadScheduledMeals(); // Reload meals for the new date
    }
  }

  void _changeDate(int days) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: days));
    });
    _loadScheduledMeals(); // Reload meals for the new date
  }

  Future<void> _toggleMealCompletion(Map<String, dynamic> meal) async {
    try {
      // Call the API to update meal completion status
      final bool newStatus = !(meal['completed'] as bool);
      await ApiServicePlanner.changeMealCompletion(meal['_id'], newStatus);
      
      // Update the local state
      setState(() {
        meal['completed'] = newStatus;
      });
      
      // Refresh meals to get updated data
      _loadScheduledMeals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating meal status: $e')),
        );
      }
    }
  }

  Future<void> _removeMeal(Map<String, dynamic> meal) async {
    try {
      // Call the API to remove the meal
      await ApiServicePlanner.removeMeal(meal['_id']);
      
      // Refresh the meals list
      _loadScheduledMeals();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing meal: $e')),
        );
      }
    }
  }

  // Navigate to recipe detail page
  void _navigateToRecipe(String recipeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => recipe_page.RecipePage(recipeId: recipeId),
      ),
    );
  }

  Widget buildDateHeader() {
    final currentLocale = Localizations.localeOf(context);
    final formattedDate =
        DateFormat.yMMMMd(currentLocale.toString()).format(selectedDate);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_left),
          onPressed: () => _changeDate(-1),
        ),
        GestureDetector(
          onTap: _pickDate,
          child: Text(
            formattedDate,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_right),
          onPressed: () => _changeDate(1),
        ),
      ],
    );
  }

  Widget _buildNutrientColumn(
      String label, IconData icon, String unit, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text('${value.toStringAsFixed(1)} $unit', style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, AppLocalizations loc) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: recipe['isProduct'] == false && recipe.containsKey('recipeId') 
          ? () => _navigateToRecipe(recipe['recipeId'])
          : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: recipe['photo'] != '' ? recipe['photo'] : 'assets/default_avatar.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: Icon(Icons.restaurant, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe['name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              recipe['time'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                recipe['category'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            // Add a visual indicator for clickable recipes
                            if (recipe['isProduct'] == false && recipe.containsKey('recipeId'))
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Display portion info below time
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            recipe['isProduct'] == true 
                              ? '${recipe['portion']} g'
                              : '${recipe['servings']} serving${recipe['servings'] > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showMealOptions(recipe),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNutrientColumn(loc.calories, Icons.local_fire_department,
                      'kcal', recipe['calories'], Colors.redAccent),
                  _buildNutrientColumn(loc.protein, Icons.scale, 'g',
                      recipe['protein'], Colors.blue),
                  _buildNutrientColumn(loc.carbs, Icons.grain, 'g',
                      recipe['carbs'], Colors.orange),
                  _buildNutrientColumn(
                      loc.fat, Icons.opacity, 'g', recipe['fat'], Colors.purple),
                  // Completion button moved to bottom right corner
                  Container(
                    decoration: BoxDecoration(
                      color: recipe['completed'] ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        recipe['completed'] 
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                        color: recipe['completed'] ? Colors.green : Colors.grey,
                        size: 28,
                      ),
                      onPressed: () => _toggleMealCompletion(recipe),
                      tooltip: recipe['completed'] ? 'Mark as not eaten' : 'Mark as eaten',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMealOptions(Map<String, dynamic> meal) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show View Recipe option only for recipes, not products
            if (meal['isProduct'] == false && meal.containsKey('recipeId'))
              ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: const Text('View Recipe Details'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToRecipe(meal['recipeId']);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove Meal'),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _removeMeal(meal);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildFluidIntakeCard(AppLocalizations loc) {
  //   // For every 0.25 L of fluid intake, assume:
  //   // 10 kcal, 0 g fat, 0 g protein, and 2 g carbs.
  //   final multiplier = fluidIntake / 0;
  //   final fluidCalories = multiplier * 0;
  //   final fluidFat = multiplier * 0;
  //   final fluidProtein = multiplier * 0;
  //   final fluidCarbs = multiplier * 0;
    
  //   return Card(
  //     elevation: 2,
  //     margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     child: Column(
  //       children: [
  //         ListTile(
  //           leading: const Icon(Icons.water, color: Colors.lightBlue, size: 30),
  //           title: Text(
  //             loc.fluidIntake,
  //             style: const TextStyle(fontWeight: FontWeight.w500),
  //           ),
  //           subtitle: Text(
  //             '${loc.consumed}: ${fluidIntake.toStringAsFixed(2)} L / ${loc.recommended}: 2.5 L',
  //           ),
  //           trailing: ElevatedButton(
  //             style: ElevatedButton.styleFrom(
  //               shape: RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.circular(20)),
  //             ),
  //             child: Text(loc.log),
  //             onPressed: () {
  //               Navigator.push(
  //                 context,
  //                 MaterialPageRoute(
  //                   builder: (context) => FluidList(),
  //                 ),
  //               ).then((_) => _loadScheduledMeals());
  //             },
  //           ),
  //         ),
  //         Padding(
  //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceAround,
  //             children: [
  //               _buildNutrientColumn(loc.calories, Icons.local_fire_department,
  //                   'kcal', fluidCalories, Colors.redAccent),
  //               _buildNutrientColumn(
  //                   loc.protein, Icons.scale, 'g', fluidProtein, Colors.blue),
  //               _buildNutrientColumn(
  //                   loc.carbs, Icons.grain, 'g', fluidCarbs, Colors.orange),
  //               _buildNutrientColumn(
  //                   loc.fat, Icons.opacity, 'g', fluidFat, Colors.purple),
  //             ],
  //           ),
  //         ),
  //         const SizedBox(height: 8),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildSummaryCard(
      List<Map<String, dynamic>> filteredRecipes, AppLocalizations loc) {
    // Calculate fluid intake nutritional values - no longer needed
    // final multiplier = fluidIntake / 0.25;
    // final fluidCalories = multiplier * 10;
    // final fluidProtein = multiplier * 0;
    // final fluidCarbs = multiplier * 2;
    // final fluidFat = multiplier * 0;

    // Sum up all meal nutritional values
    double totalKcal =
        filteredRecipes.fold(0.0, (sum, item) => sum + (item['calories'] as double));
    double totalProtein =
        filteredRecipes.fold(0.0, (sum, item) => sum + (item['protein'] as double));
    double totalCarbs =
        filteredRecipes.fold(0.0, (sum, item) => sum + (item['carbs'] as double));
    double totalFat =
        filteredRecipes.fold(0.0, (sum, item) => sum + (item['fat'] as double));
    
    // No longer adding fluid intake to totals
    // totalKcal += fluidCalories;
    // totalProtein += fluidProtein;
    // totalCarbs += fluidCarbs;
    // totalFat += fluidFat;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              loc.dailySummary,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientColumn(loc.calories, Icons.local_fire_department,
                    'kcal', totalKcal, Colors.redAccent),
                _buildNutrientColumn(
                    loc.protein, Icons.scale, 'g', totalProtein, Colors.blue),
                _buildNutrientColumn(
                    loc.carbs, Icons.grain, 'g', totalCarbs, Colors.orange),
                _buildNutrientColumn(
                    loc.fat, Icons.opacity, 'g', totalFat, Colors.purple),
              ],
            ),
            // Update note to indicate fluid intake is not included
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '(Fluid intake tracked separately)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayPlan(AppLocalizations loc) {
    // Filter recipes based on selectedDate.
    final filteredRecipes = scheduledRecipes
        .where((recipe) => _isSameDay(recipe['date'], selectedDate))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildDateHeader(),
        const SizedBox(height: 16),
        _buildSummaryCard(filteredRecipes, loc),
        const SizedBox(height: 16),
        // _buildFluidIntakeCard(loc),
        // const SizedBox(height: 16),
        filteredRecipes.isEmpty
            ? Column(
                children: [
                  Text(
                    loc.noRecipesPlanned,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditPlannerPage(
                            selectedDate: selectedDate,
                          ),
                        ),
                      ).then((_) => _loadScheduledMeals());
                    },
                    child: Text(loc.editDay),
                  ),
                ],
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredRecipes.length,
                itemBuilder: (context, index) {
                  final recipe = filteredRecipes[index];
                  return _buildRecipeCard(recipe, loc);
                },
              ),
        const SizedBox(height: 60),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: NavigationPlannerAppBar(currentPage: 'planner'),
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
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: RefreshIndicator(
            onRefresh: _loadScheduledMeals,
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    key: ValueKey(selectedDate),
                    child: _buildDayPlan(loc),
                  ),
                ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green.shade100,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditPlannerPage(selectedDate: selectedDate),
            ),
          ).then((_) => _loadScheduledMeals()); // Refresh after editing
        },
        child: const Icon(Icons.edit),
      ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 0),
    );
  }
}
