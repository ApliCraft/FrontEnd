import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decideat/models/shopping_list.dart';
import 'package:decideat/api/api.dart';
import 'package:http/http.dart' as http;

class ShoppingListService {
  static const String _storageKey = 'shopping_lists';
  
  // Get all shopping lists
  static Future<List<ShoppingList>> getAllLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      
      if (jsonString == null) {
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => ShoppingList.fromJson(json)).toList();
    } catch (e) {
      print('Error getting shopping lists: $e');
      return [];
    }
  }
  
  // Save a shopping list
  static Future<bool> saveList(ShoppingList list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lists = await getAllLists();
      
      // Check if list exists and update it, otherwise add new
      final existingIndex = lists.indexWhere((item) => item.id == list.id);
      if (existingIndex >= 0) {
        lists[existingIndex] = list;
      } else {
        lists.add(list);
      }
      
      final jsonString = json.encode(lists.map((list) => list.toJson()).toList());
      return await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      print('Error saving shopping list: $e');
      return false;
    }
  }
  
  // Delete a shopping list
  static Future<bool> deleteList(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lists = await getAllLists();
      
      final newLists = lists.where((list) => list.id != id).toList();
      final jsonString = json.encode(newLists.map((list) => list.toJson()).toList());
      return await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      print('Error deleting shopping list: $e');
      return false;
    }
  }
  
  // Generate shopping list from meal plan
  static Future<ShoppingList?> generateFromMealPlan(DateTime startDate, DateTime endDate, String listName) async {
    try {
      // TODO: Replace with actual API call when backend is ready
      // This would fetch ingredients from planned meals in the date range
      
      // For now, create a sample list with common ingredients using the app's product categories
      final shoppingList = ShoppingList(
        name: listName,
        isFromMealPlan: true,
        items: [
          ShoppingListItem(name: 'Chicken breast', quantity: 500, unit: 'g', category: 'Meat'),
          ShoppingListItem(name: 'Rice', quantity: 250, unit: 'g', category: 'Cereal products'),
          ShoppingListItem(name: 'Broccoli', quantity: 1, unit: 'pcs', category: 'Vegetables'),
          ShoppingListItem(name: 'Olive oil', quantity: 50, unit: 'ml', category: 'Fluids'),
          ShoppingListItem(name: 'Eggs', quantity: 6, unit: 'pcs', category: 'Dairy'),
          ShoppingListItem(name: 'Milk', quantity: 1, unit: 'l', category: 'Dairy'),
          ShoppingListItem(name: 'Apples', quantity: 4, unit: 'pcs', category: 'Fruits'),
          ShoppingListItem(name: 'Bread', quantity: 1, unit: 'pcs', category: 'Cereal products'),
          ShoppingListItem(name: 'Salmon', quantity: 300, unit: 'g', category: 'Fish and Seafood'),
          ShoppingListItem(name: 'Almonds', quantity: 100, unit: 'g', category: 'Nuts'),
          ShoppingListItem(name: 'Dark chocolate', quantity: 1, unit: 'pcs', category: 'Sweets and Snacks'),
        ],
      );
      
      // Save the generated list
      await saveList(shoppingList);
      
      return shoppingList;
    } catch (e) {
      print('Error generating shopping list from meal plan: $e');
      return null;
    }
  }
}