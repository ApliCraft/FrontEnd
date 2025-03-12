import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';
import '../models/planner.dart';

class ApiServicePlanner {
  // Add meal (product or recipe) to the planner
  static Future<Map<String, dynamic>> addMeal({
    required String date,
    required String type,
    required String id,
    required String category,
    required double portion,
  }) async {
    try {
      await RefreshTokenIfExpired();
      final accessToken = await storage.read(key: 'accessToken');
      
      // Ensure portion is a valid positive double
      double safePortion = portion;
      if (safePortion <= 0) {
        safePortion = type == 'product' ? 100.0 : 1.0;
      }
      
      // Round to 1 decimal place for cleaner values
      safePortion = double.parse(safePortion.toStringAsFixed(1));
      
      // Format the request body to match the expected format
      final requestBody = {
        'date': date,
        'type': type,
        '_id': id,  // Use _id instead of id
        'category': category.toLowerCase(),  // Ensure category is lowercase
        'portion': safePortion,  // Use 'portion' for both products and recipes
      };
      
      // Print debug info for troubleshooting
      print('AddMeal Request: $requestBody');
      print('Portion value: $safePortion (${safePortion.runtimeType})');
      
      final url = Uri.parse('$apiUrl/user/planner/add-meal');
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(requestBody),
      );
      
      // Print response for debugging
      print('AddMeal Response Status: ${response.statusCode}');
      print('AddMeal Response Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Even if the response is a string, we'll return a Map to maintain the expected return type
        return {'success': true, 'message': response.body};
      } else {
        throw Exception('Failed to add meal to planner: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('Exception in ApiServicePlanner.addMeal: $e');
      print('Error type: ${e.runtimeType}');
      throw Exception('API error: $e');
    }
  }
  
  // Get planner data for a specific date
  static Future<PlannerDay> getMeals(String date) async {
    try {
      await RefreshTokenIfExpired();
      final accessToken = await storage.read(key: 'accessToken');
      
      final url = Uri.parse('$apiUrl/user/planner/meals');
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'date': date,
        }),
      );
      
      // Print response for debugging
      print('GetMeals Response Status: ${response.statusCode}');
      print('GetMeals Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return PlannerDay.fromJson(data);
      } else if (response.statusCode == 404) {
        // Return empty planner when no data exists
        print('No meals found for date: $date, returning empty planner');
        return PlannerDay(
          id: '',
          day: date,
          userId: '',
          fluidIntakeAmount: 0,
          planner: Planner(
            id: '',
            fluids: [],
            meals: [],
          ),
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
      } else {
        print('Error getting meals: ${response.statusCode}');
        // Return empty planner for other errors instead of throwing
        return PlannerDay(
          id: '',
          day: date,
          userId: '',
          fluidIntakeAmount: 0,
          planner: Planner(
            id: '',
            fluids: [],
            meals: [],
          ),
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      print('Exception in ApiServicePlanner.getMeals: $e');
      print('Error type: ${e.runtimeType}');
      // Return empty planner on error instead of throwing
      return PlannerDay(
        id: '',
        day: date,
        userId: '',
        fluidIntakeAmount: 0,
        planner: Planner(
          id: '',
          fluids: [],
          meals: [],
        ),
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
    }
  }
  
  // Remove meal from planner
  static Future<bool> removeMeal(String mealId) async {
    await RefreshTokenIfExpired();
    final accessToken = await storage.read(key: 'accessToken');
    
    final url = Uri.parse('$apiUrl/user/planner/remove-meal/$mealId');
    final response = await http.delete(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
    );
    
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to remove meal: ${response.statusCode}');
    }
  }
  
  // Get daily nutritional summary
  static Future<NutritionalSummary> getDailyNutritionalSummary(String date) async {
    try {
      // Create empty nutritional summary with MacroNutrients objects
      final emptyMacros = MacroNutrients(
        calories: 0.0,
        proteins: 0.0,
        fats: 0.0,
        carbs: 0.0,
      );
      
      final emptySummary = NutritionalSummary(
        planned: emptyMacros,
        consumed: emptyMacros,
      );

      // First check if there are any meals planned for this date
      try {
        final plannerData = await getMeals(date);
        if (plannerData.planner.meals.isEmpty) {
          print('No meals planned for $date, returning empty nutritional summary');
          return emptySummary;
        }
      } catch (e) {
        // If getMeals fails (404 or other error), return empty summary
        print('Error getting meals for $date: $e');
        return emptySummary;
      }

      await RefreshTokenIfExpired();
      final accessToken = await storage.read(key: 'accessToken');
      
      final url = Uri.parse('$apiUrl/user/planner/daily-nutritional-summary');
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'date': date,
        }),
      );
      
      // Print response for debugging
      print('GetDailyNutritionalSummary Response Status: ${response.statusCode}');
      print('GetDailyNutritionalSummary Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return NutritionalSummary.fromJson(data);
      } else if (response.statusCode == 404) {
        // Return empty nutritional summary when no data exists
        print('404 response for nutritional data, returning empty summary');
        return emptySummary;
      } else {
        print('Error getting nutritional summary: ${response.statusCode}');
        return emptySummary; // Return empty summary instead of throwing
      }
    } catch (e) {
      print('Exception in ApiServicePlanner.getDailyNutritionalSummary: $e');
      print('Error type: ${e.runtimeType}');
      
      // Return empty nutritional summary with MacroNutrients objects
      return NutritionalSummary(
        planned: MacroNutrients(
          calories: 0.0,
          proteins: 0.0,
          fats: 0.0,
          carbs: 0.0,
        ),
        consumed: MacroNutrients(
          calories: 0.0,
          proteins: 0.0,
          fats: 0.0,
          carbs: 0.0,
        ),
      );
    }
  }
  
  // Change meal completion status
  static Future<bool> changeMealCompletion(String mealId, bool completed) async {
    await RefreshTokenIfExpired();
    final accessToken = await storage.read(key: 'accessToken');
    
    final url = Uri.parse('$apiUrl/user/planner/change-completion/$mealId');
    final response = await http.patch(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'completed': completed,
      }),
    );
    
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to change meal completion status: ${response.statusCode}');
    }
  }
} 