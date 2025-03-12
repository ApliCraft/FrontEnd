import 'package:decideat/notifications/notifications_service.dart';
import 'package:flutter/material.dart';
import 'package:decideat/widgets/bottomNavBar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/api/api.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:decideat/api/user.dart' as user_api;
import 'package:decideat/pages/chat/chat.dart';
import 'dart:math' as math;
import 'package:decideat/pages/planner.dart';
import 'package:decideat/pages/planner/fluid_list.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

// Model class for NutritionalSummary
class NutrientData {
  final double calories;
  final double proteins;
  final double fats;
  final double carbs;

  NutrientData({
    required this.calories,
    required this.proteins,
    required this.fats,
    required this.carbs,
  });

  factory NutrientData.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert values to double
    double safeToDouble(dynamic value, double defaultValue) {
      if (value == null) return defaultValue;
      
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (_) {
          return defaultValue;
        }
      }
      return defaultValue;
    }
    
    // Parse all values safely
    return NutrientData(
      calories: safeToDouble(json['calories'], 0.0),
      proteins: safeToDouble(json['proteins'], 0.0),
      fats: safeToDouble(json['fats'], 0.0),
      carbs: safeToDouble(json['carbs'], 0.0),
    );
  }

  // Helper to create an empty nutrient data object
  factory NutrientData.empty() {
    return NutrientData(
      calories: 0,
      proteins: 0,
      fats: 0,
      carbs: 0,
    );
  }
}

class NutritionalSummary {
  final NutrientData planned;
  final NutrientData consumed;

  NutritionalSummary({
    required this.planned,
    required this.consumed,
  });

  factory NutritionalSummary.fromJson(Map<String, dynamic> json) {
    return NutritionalSummary(
      planned: NutrientData.fromJson(json['planned'] ?? {}),
      consumed: NutrientData.fromJson(json['consumed'] ?? {}),
    );
  }

  // Helper to create an empty summary with default values
  factory NutritionalSummary.empty() {
    return NutritionalSummary(
      planned: NutrientData(calories: 2500, proteins: 150, fats: 80, carbs: 300),
      consumed: NutrientData.empty(),
    );
  }

  // Get progress ratios for each nutrient (consumed/planned)
  double get caloriesProgress => 
      (planned.calories > 0 && consumed.calories >= 0)
          ? (consumed.calories / planned.calories).clamp(0.0, 1.0) 
          : 0.0;
  
  double get proteinsProgress => 
      (planned.proteins > 0 && consumed.proteins >= 0)
          ? (consumed.proteins / planned.proteins).clamp(0.0, 1.0) 
          : 0.0;
  
  double get fatsProgress => 
      (planned.fats > 0 && consumed.fats >= 0)
          ? (consumed.fats / planned.fats).clamp(0.0, 1.0) 
          : 0.0;
  
  double get carbsProgress => 
      (planned.carbs > 0 && consumed.carbs >= 0)
          ? (consumed.carbs / planned.carbs).clamp(0.0, 1.0) 
          : 0.0;

  // Format summary strings with 2 decimal places
  String get caloriesSummary => 
      '${consumed.calories.toStringAsFixed(0)} kcal / ${planned.calories.toStringAsFixed(0)} kcal';
  
  String get proteinsSummary => 
      '${consumed.proteins.toStringAsFixed(1)} g / ${planned.proteins.toStringAsFixed(1)} g';
  
  String get fatsSummary => 
      '${consumed.fats.toStringAsFixed(1)} g / ${planned.fats.toStringAsFixed(1)} g';
  
  String get carbsSummary => 
      '${consumed.carbs.toStringAsFixed(1)} g / ${planned.carbs.toStringAsFixed(1)} g';
}

// Model class for FluidIntake
class FluidIntake {
  final int consumed;
  final int amount;
  final String dateString;

  FluidIntake({
    required this.consumed,
    required this.amount,
    this.dateString = '',
  });

  factory FluidIntake.fromJson(Map<String, dynamic> json) {
    // Safely parse and convert values
    int consumed = 0;
    int amount = 2000;
    String dateString = '';
    
    // Handle dateString field
    if (json.containsKey('dateString')) {
      dateString = json['dateString']?.toString() ?? '';
    }
    
    // Handle consumed field safely
    if (json.containsKey('consumed')) {
      if (json['consumed'] is int) {
        consumed = json['consumed'];
      } else if (json['consumed'] is String) {
        try {
          consumed = int.parse(json['consumed']);
        } catch (_) {
          consumed = 0;
        }
      } else if (json['consumed'] is double) {
        consumed = json['consumed'].round();
      }
    }
    
    // Handle amount field safely
    if (json.containsKey('amount')) {
      if (json['amount'] is int) {
        amount = json['amount'];
      } else if (json['amount'] is String) {
        try {
          amount = int.parse(json['amount']);
        } catch (_) {
          amount = 2000;
        }
      } else if (json['amount'] is double) {
        amount = json['amount'].round();
      }
    }
    
    // Ensure values are within valid ranges
    consumed = consumed < 0 ? 0 : consumed;
    amount = amount <= 0 ? 2000 : amount;
    
    return FluidIntake(
      consumed: consumed,
      amount: amount,
      dateString: dateString,
    );
  }

  // Get progress as a double between 0.0 and 1.0
  double get progress => amount > 0 ? (consumed / amount).clamp(0.0, 1.0) : 0.0;
  
  // Format consumed and amount in liters with one decimal place
  String get formattedText => '${(consumed / 1000).toStringAsFixed(1)} L / ${(amount / 1000).toStringAsFixed(1)} L';
  
  // Number of filled fluid icons (each represents 250ml)
  int get filledIcons => consumed > 0 ? (consumed / 250).round() : 0;
  
  // Total number of fluid icons
  int get totalIcons => amount > 0 ? (amount / 250).round() : 10;
}

// Model class for NextMeal
class NextMeal {
  final String id;
  final String category;
  final String time;
  final bool completed;
  final List<RecipeItem> recipes;
  final List<ProductItem> products;

  NextMeal({
    required this.id,
    required this.category,
    required this.time,
    required this.completed,
    required this.recipes,
    required this.products,
  });

  factory NextMeal.fromJson(Map<String, dynamic> json) {
    return NextMeal(
      id: json['_id'] ?? '',
      category: json['category'] ?? '',
      time: json['time'] ?? '',
      completed: json['completed'] ?? false,
      recipes: (json['recipes'] as List<dynamic>?)
              ?.map((recipe) => RecipeItem.fromJson(recipe))
              .toList() ??
          [],
      products: (json['products'] as List<dynamic>?)
              ?.map((product) => ProductItem.fromJson(product))
              .toList() ??
          [],
    );
  }
}

class RecipeItem {
  final String recipeId;
  final double portion;

  RecipeItem({
    required this.recipeId,
    required this.portion,
  });

  factory RecipeItem.fromJson(Map<String, dynamic> json) {
    return RecipeItem(
      recipeId: json['recipeId'] ?? '',
      portion: json['portion'] is int 
          ? (json['portion'] as int).toDouble() 
          : json['portion'] ?? 1.0,
    );
  }
}

class ProductItem {
  final String productId;
  final double amount;

  ProductItem({
    required this.productId,
    required this.amount,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      productId: json['productId'] ?? '',
      amount: json['amount'] is int 
          ? (json['amount'] as int).toDouble() 
          : json['amount'] ?? 0.0,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final NotificationsService _notificationsService = NotificationsService();
  String _username = "";
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  NextMeal? _nextMeal;
  bool _isLoadingNextMeal = false;
  String? _nextMealError;
  
  // Fluid intake data
  FluidIntake? _fluidIntake;
  bool _isLoadingFluidIntake = false;
  String? _fluidIntakeError;
  
  // Nutritional summary data
  NutritionalSummary? _nutritionalSummary;
  bool _isLoadingNutritionalSummary = false;
  String? _nutritionalSummaryError;
  bool _noPlannerExists = false;
  
  // Recipe name cache to avoid multiple API calls
  Map<String, String> _recipeNames = {};

  @override
  void initState() {
    super.initState();
    _initializeApp();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Create a pulse animation
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Make the animation repeat in both directions
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Initialize app data with token validation
  Future<void> _initializeApp() async {
    try {
      // First validate token
      await RefreshTokenIfExpired();
      
      // Then get user data and start API calls
      _getUsername().then((value) => setState(() {
            _username = value;
          }));
      await _initializeNotifications();
      
      // Start API calls after ensuring token is valid
      _fetchNextMeal();
      _fetchFluidIntake();
      _fetchNutritionalSummary();
    } catch (e) {
      print('Error initializing app: ${e.toString()}');
    }
  }

  Future<void> _initializeNotifications() async {
    await _notificationsService.initNotifications();
  }

  Future<String> _getUsername() async {
    return await user_api.getUsername();
  }
  
  // Fetch next meal from API
  Future<void> _fetchNextMeal() async {
    setState(() {
      _isLoadingNextMeal = true;
      _nextMealError = null;
    });
    
    try {
      final response = await _makeAuthenticatedRequest(
        '$apiUrl/user/planner/next-meals',
        'GET',
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final nextMeal = NextMeal.fromJson(data[0]);
          setState(() {
            _nextMeal = nextMeal;
            _isLoadingNextMeal = false;
          });
          
          // Fetch recipe names if there are recipes
          if (_nextMeal!.recipes.isNotEmpty) {
            _fetchRecipeNames();
          }
        } else {
          setState(() {
            _nextMeal = null;
            _isLoadingNextMeal = false;
          });
        }
        
        return;
      } else {
        setState(() {
          _nextMealError = 'Failed to load next meal: ${response.statusCode}';
          _isLoadingNextMeal = false;
        });
      }
    } catch (e) {
      setState(() {
        _nextMealError = 'Error: ${e.toString()}';
        _isLoadingNextMeal = false;
      });
    }
  }
  
  // Fetch recipe names for the next meal
  Future<void> _fetchRecipeNames() async {
    if (_nextMeal == null || _nextMeal!.recipes.isEmpty) return;
    
    try {
      for (var recipe in _nextMeal!.recipes) {
        // Skip if we already have the recipe name
        if (_recipeNames.containsKey(recipe.recipeId)) continue;
        
        final response = await _makeAuthenticatedRequest(
          '$apiUrl/recipe/${recipe.recipeId}',
          'GET',
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _recipeNames[recipe.recipeId] = data['name'] ?? 'Unknown Recipe';
          });
        }
      }
    } catch (e) {
      print('Error fetching recipe names: ${e.toString()}');
    }
  }
  
  // Fetch fluid intake data from API
  Future<void> _fetchFluidIntake() async {
    setState(() {
      _isLoadingFluidIntake = true;
      _fluidIntakeError = null;
    });
    
    try {
      // Get current date in the correct format (YYYY-MM-DD)
      final today = DateTime.now();
      final formattedDate = DateFormat("yyyy-MM-dd").format(today);
      
      print('Fetching fluid intake for date: $formattedDate');
      
      final response = await _makeAuthenticatedRequest(
        '$apiUrl/user/planner/fluid-count',
        'POST',
        body: {
          'date': formattedDate,
        },
      );
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          print('Fluid intake response: $data');
          
          // Validate the data is in expected format
          if (data != null && data is Map<String, dynamic>) {
            setState(() {
              _fluidIntake = FluidIntake.fromJson(data);
              _isLoadingFluidIntake = false;
            });
          } else {
            // Handle unexpected data format
            setState(() {
              _fluidIntakeError = 'Invalid data format received';
              _fluidIntake = FluidIntake(consumed: 0, amount: 2500);
              _isLoadingFluidIntake = false;
            });
            print('Unexpected fluid intake data format: $data');
          }
        } catch (e) {
          // Handle JSON parse errors
          setState(() {
            _fluidIntakeError = 'Error parsing data: ${e.toString()}';
            _fluidIntake = FluidIntake(consumed: 0, amount: 2500);
            _isLoadingFluidIntake = false;
          });
          print('JSON parse error in fluid intake: $e');
        }
      } else {
        setState(() {
          _fluidIntakeError = 'Failed to load fluid intake: ${response.statusCode}';
          _fluidIntake = FluidIntake(consumed: 0, amount: 2500);
          _isLoadingFluidIntake = false;
        });
        print('Fluid intake error: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _fluidIntakeError = 'Error: ${e.toString()}';
        _fluidIntake = FluidIntake(consumed: 0, amount: 2500);
        _isLoadingFluidIntake = false;
      });
      print('Exception in _fetchFluidIntake: $e');
    }
  }
  
  // Fetch nutritional summary from API
  Future<void> _fetchNutritionalSummary() async {
    setState(() {
      _isLoadingNutritionalSummary = true;
      _nutritionalSummaryError = null;
      _noPlannerExists = false;
    });
    
    try {
      // Get current date in the correct format (YYYY-MM-DD)
      final today = DateTime.now();
      final formattedDate = DateFormat("yyyy-MM-dd").format(today);
      
      print('Fetching nutritional summary for date: $formattedDate');
      
      final response = await _makeAuthenticatedRequest(
        '$apiUrl/user/planner/daily-nutritional-summary',
        'POST',
        body: {
          'date': formattedDate,
        },
      );
      
      print('Nutritional summary response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = response.body;
        print('Nutritional summary response body: $responseBody');
        
        // Check if no planner exists
        if (responseBody == "planner not found, maybe it doesn't exist?") {
          setState(() {
            _nutritionalSummary = NutritionalSummary.empty();
            _isLoadingNutritionalSummary = false;
            _noPlannerExists = true;
          });
        } else {
          try {
            final data = json.decode(responseBody);
            
            // Validate data has expected structure
            if (data != null && data is Map<String, dynamic>) {
              setState(() {
                _nutritionalSummary = NutritionalSummary.fromJson(data);
                _isLoadingNutritionalSummary = false;
              });
            } else {
              // Handle unexpected data format
              setState(() {
                _nutritionalSummaryError = 'Invalid data format received';
                _nutritionalSummary = NutritionalSummary.empty();
                _isLoadingNutritionalSummary = false;
              });
              print('Unexpected data format: $data');
            }
          } catch (e) {
            // Handle JSON parse errors
            setState(() {
              _nutritionalSummaryError = 'Error parsing data: ${e.toString()}';
              _nutritionalSummary = NutritionalSummary.empty();
              _isLoadingNutritionalSummary = false;
            });
            print('JSON parse error: $e');
          }
        }
      } else {
        setState(() {
          _nutritionalSummaryError = 'Failed to load nutritional summary: ${response.statusCode}';
          _nutritionalSummary = NutritionalSummary.empty();
          _isLoadingNutritionalSummary = false;
        });
        print('Nutritional summary error: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _nutritionalSummaryError = 'Error: ${e.toString()}';
        _nutritionalSummary = NutritionalSummary.empty();
        _isLoadingNutritionalSummary = false;
      });
      print('Exception in _fetchNutritionalSummary: $e');
    }
  }
  
  // Format time from 24h to 12h format
  String _formatTime(String time) {
    try {
      final timeParts = time.split(':');
      if (timeParts.length != 2) return time;
      
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      
      return '$hour12:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time;
    }
  }
  
  // Format meal category for display
  String _formatCategory(String category) {
    if (category.isEmpty) return '';
    return category.substring(0, 1).toUpperCase() + category.substring(1);
  }
  
  // Navigate to planner page
  void _navigateToPlanner() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const PlannerPage(),
      ),
    );
  }

  // Navigate to fluid list page
  void _navigateToFluidList() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FluidList(),
      ),
    );
  }

  // Check if the page contains a method to build the body
  void _navigateToChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatPage(),
      ),
    );
  }

  // Refresh data with feedback to the user
  Future<void> _refreshData() async {
    try {
      // Ensure token is valid before all API calls
      await RefreshTokenIfExpired();
      
      await Future.wait([
        _fetchNextMeal(),
        _fetchFluidIntake(),
        _fetchNutritionalSummary(),
      ]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Information updated'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${e.toString()}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to make authenticated API calls with token validation
  Future<http.Response> _makeAuthenticatedRequest(
    String url, 
    String method, 
    {Map<String, dynamic>? body}
  ) async {
    // Always refresh token before making API call
    await RefreshTokenIfExpired();
    final accessToken = await storage.read(key: 'accessToken');
    
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $accessToken',
    };
    
    final Uri uri = Uri.parse(url);
    http.Response response;
    
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri, 
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          uri, 
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
    
    return response;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 800;

    return Scaffold(
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
            onRefresh: _refreshData,
            color: Colors.green,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: isLargeScreen
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: _buildContent(context, loc),
                      ),
                    )
                  : _buildContent(context, loc),
            ),
          ),
        ),
      ),
      // ChatBot ICON
      floatingActionButton: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10 * _pulseAnimation.value,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: () => _navigateToChat(context),
                backgroundColor: Colors.green.shade300,
                foregroundColor: Colors.white,
                elevation: 0, // We use custom shadow in the Container
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 26),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                tooltip: 'Chat with AI Assistant',
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const BottomNavBar(initialIndex: 2),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations loc) {
    // Using the localized strings for all texts.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Welcoming Message with notifications button
        Stack(
          children: [
            // The welcome message container that can wrap
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 30, 0),
              child: Container(
                width: MediaQuery.of(context).size.width *
                    0.85, // Give space for the bell icon
                child: Text(
                  loc.welcome(_username),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
            // The notification bell positioned at the top right
            Positioned(
              top: 0,
              right: -12,
              
              child: IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () async {
                  final now = DateTime.now();
                  final scheduledDateTime = tz.TZDateTime(tz.local, now.year,
                      now.month, now.day, now.hour, now.minute + 1);

                  print('TimezoneDayTimeScheduled: $scheduledDateTime');
                  if (context.mounted) {
                    await _notificationsService.scheduleNotification(
                        context: context,
                        title: 'Decideat',
                        body: 'You have a new notification!',
                        scheduledDate: scheduledDateTime);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Notification scheduled for ${scheduledDateTime.toString()}')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Next Meal Widget
        GestureDetector(
          onTap: _navigateToPlanner,
          child: Card(
            color: Colors.green.shade50,
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _isLoadingNextMeal
                  ? _buildLoadingShimmer(context)
                  : _nextMealError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Could not load next meal. Please try again later.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : _nextMeal == null
                          ? _buildNoMealWidget(context, loc)
                          : _buildNextMealWidget(context, loc),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Nutritional Summary Card with icons
        GestureDetector(
          onTap: _navigateToPlanner,
          child: Card(
            color: Colors.grey.shade50,
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _isLoadingNutritionalSummary
                  ? _buildNutritionalLoadingShimmer(context)
                  : _nutritionalSummaryError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Could not load nutritional data.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : _buildNutritionalSummaryContent(context, loc),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Fluid Widget Card with custom water icon progress bar
        GestureDetector(
          onTap: _navigateToFluidList,
          child: Card(
            color: Colors.lightBlue.shade50,
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _isLoadingFluidIntake
                  ? _buildFluidLoadingShimmer(context)
                  : _fluidIntakeError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Could not load fluid intake data.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : _buildFluidIntakeWidget(context, loc),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Chat button
        // _buildChatButton(context),
      ],
    );
  }

  Widget _buildMetricRow({
    required String label,
    required double progress,
    required Color color,
    required String summary,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                  value: progress,
                  color: color,
                  backgroundColor: color.withOpacity(0.3)),
              const SizedBox(height: 4),
              Text(summary,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFluidProgress(double current, double recommended) {
    // Always show exactly 10 water icons
    const int totalIcons = 10;
    // Calculate filled icons based on progress proportion, ensure current is valid
    if (current <= 0 || recommended <= 0) {
      return Wrap(
        children: List.generate(totalIcons, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Icon(
              Icons.water_drop,
              color: Colors.blue.withOpacity(0.3),
              size: 20,
            ),
          );
        }),
      );
    }
    
    int filledIcons = (current / recommended * totalIcons).round().clamp(0, totalIcons);
    
    return Wrap(
      children: List.generate(totalIcons, (index) {
        bool filled = index < filledIcons;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Icon(
            Icons.water_drop,
            color: filled ? Colors.blue : Colors.blue.withOpacity(0.3),
            size: 20,
          ),
        );
      }),
    );
  }

  Widget _buildNoMealWidget(BuildContext context, AppLocalizations loc) {
    return Row(
      children: [
        const Icon(Icons.restaurant_menu, size: 40, color: Colors.green),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.nextMeal,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('No meals planned for today',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text('Tap to plan your next meal',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        IconButton(
          onPressed: _navigateToPlanner,
          icon: const Icon(Icons.arrow_forward, color: Colors.green),
        ),
      ],
    );
  }

  Widget _buildNextMealWidget(BuildContext context, AppLocalizations loc) {
    final formattedTime = _formatTime(_nextMeal!.time);
    final category = _formatCategory(_nextMeal!.category);
    
    // Build recipe names list
    String recipesText = '';
    if (_nextMeal!.recipes.isNotEmpty) {
      final recipeNames = _nextMeal!.recipes.map((recipe) {
        final name = _recipeNames[recipe.recipeId] ?? 'Loading...';
        return '$name (${recipe.portion}x)';
      }).join(', ');
      recipesText = recipeNames;
    }
    
    // Build products list (if implemented in the future)
    String productsText = '';
    if (_nextMeal!.products.isNotEmpty) {
      productsText = '${_nextMeal!.products.length} products';
    }
    
    // Combine recipes and products
    String mealItems = '';
    if (recipesText.isNotEmpty) {
      mealItems = recipesText;
    }
    if (productsText.isNotEmpty) {
      mealItems = mealItems.isEmpty ? productsText : '$mealItems, $productsText';
    }
    
    return Row(
      children: [
        const Icon(Icons.restaurant_menu, size: 40, color: Colors.green),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Next $category',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                mealItems.isEmpty ? 'Meal details loading...' : mealItems,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text('Scheduled for $formattedTime',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        IconButton(
          onPressed: _navigateToPlanner,
          tooltip: 'View in planner',
          icon: const Icon(Icons.arrow_forward, color: Colors.green),
        ),
      ],
    );
  }

  Widget _buildLoadingShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 18,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluidIntakeWidget(BuildContext context, AppLocalizations loc) {
    // Use a default if fluid data is null or has invalid values
    final fluidData = _fluidIntake ?? FluidIntake(consumed: 0, amount: 2500);
    
    // Ensure we have valid values to display
    final consumed = fluidData.consumed >= 0 ? fluidData.consumed : 0;
    final amount = fluidData.amount > 0 ? fluidData.amount : 2500;
    
    // Safely calculate formatted text
    final String formattedText = '${(consumed / 1000).toStringAsFixed(1)} L / ${(amount / 1000).toStringAsFixed(1)} L';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_drink, size: 40, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loc.fluidIntake,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (fluidData.dateString.isNotEmpty)
                        Text(
                          fluidData.dateString,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Custom fluid progress bar built from water icons
                  Wrap(
                    direction: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 8, 4),
                        child: _buildFluidProgress(
                          // Use safer calculations instead of depending on the model getters
                          consumed > 0 ? (consumed / 250).toDouble() : 0,
                          amount > 0 ? (amount / 250).toDouble() : 10,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          formattedText,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _navigateToFluidList,
            child: Text(loc.addFluid),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade50,
              foregroundColor: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFluidLoadingShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 18,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(
                    10,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionalLoadingShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title shimmer
          Container(
            height: 20,
            width: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          
          // Calories row shimmer
          _buildMetricRowShimmer(),
          const SizedBox(height: 12),
          
          // Protein row shimmer
          _buildMetricRowShimmer(),
          const SizedBox(height: 12),
          
          // Carbs row shimmer
          _buildMetricRowShimmer(),
          const SizedBox(height: 12),
          
          // Fat row shimmer
          _buildMetricRowShimmer(),
        ],
      ),
    );
  }
  
  // Helper to build a shimmer for a metric row
  Widget _buildMetricRowShimmer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon shimmer
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label shimmer
              Container(
                height: 14,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              // Progress bar shimmer
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              // Summary shimmer
              Container(
                height: 10,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionalSummaryContent(BuildContext context, AppLocalizations loc) {
    // Initialize with empty values if nutritional summary is null (shouldn't happen)
    final summary = _nutritionalSummary ?? NutritionalSummary.empty();
    
    // Format today's date for display
    final String formattedTodayDate = DateFormat("yyyy-MM-dd").format(DateTime.now());
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(loc.dailyNutritionalSummary,
                style: Theme.of(context).textTheme.titleMedium),
            Text(
              formattedTodayDate,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (_noPlannerExists)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'No planner exists for this date. Tap to create one.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.amber[800],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        _buildMetricRow(
            label: loc.calories,
            progress: summary.caloriesProgress,
            color: Colors.redAccent,
            summary: summary.caloriesSummary,
            icon: Icons.local_fire_department),
        const SizedBox(height: 12),
        _buildMetricRow(
            label: loc.protein,
            progress: summary.proteinsProgress,
            color: Colors.blue,
            summary: summary.proteinsSummary,
            icon: Icons.fitness_center),
        const SizedBox(height: 12),
        _buildMetricRow(
            label: loc.carbs,
            progress: summary.carbsProgress,
            color: Colors.orange,
            summary: summary.carbsSummary,
            icon: Icons.grain),
        const SizedBox(height: 12),
        _buildMetricRow(
            label: loc.fat,
            progress: summary.fatsProgress,
            color: Colors.purple,
            summary: summary.fatsSummary,
            icon: Icons.opacity),
      ],
    );
  }

  Widget _buildChatButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: () => _navigateToChat(context),
        icon: const Icon(Icons.chat),
        label: const Text('Chat with AI'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
