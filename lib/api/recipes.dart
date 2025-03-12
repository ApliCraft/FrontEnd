import 'package:http/http.dart' as http;
import './recipe.dart';
import 'dart:convert';
import 'user.dart';
import 'api.dart';


// Connect to the API
// Get all recipes from localhost:4000/recipe/get


class ApiServiceRecipes {
  static Future<List<Recipe>> getRecipes() async {
    final url = Uri.parse('$apiUrl/recipe/get');
    final response = await http.post(url, headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    }, body: jsonEncode(<String, bool>{
        "sendImages": true,
    }));
    if (response.statusCode == 200) {
      List<dynamic> jsonResponse = json.decode(response.body);
      var userId = await storage.read(key: 'userId');
      return jsonResponse.map((recipe) => Recipe.fromJson(recipe, userId)).toList();
    } else {
      throw Exception('Failed to load recipes from API');
    }
  }
}