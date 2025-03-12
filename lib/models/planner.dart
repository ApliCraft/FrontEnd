class PlannerDay {
  final String id;
  final String day;
  final String userId;
  final int fluidIntakeAmount;
  final Planner planner;
  final String createdAt;
  final String updatedAt;

  PlannerDay({
    required this.id,
    required this.day,
    required this.userId,
    required this.fluidIntakeAmount,
    required this.planner,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlannerDay.fromJson(Map<String, dynamic> json) {
    return PlannerDay(
      id: json['_id'] ?? '',
      day: json['day'] ?? '',
      userId: json['userId'] ?? '',
      fluidIntakeAmount: json['fluidIntakeAmount'] ?? 0,
      planner: Planner.fromJson(json['planner'] ?? {}),
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }
}

class Planner {
  final String id;
  final List<Fluid> fluids;
  List<Meal> meals;  // Changed to non-final to allow sorting

  Planner({
    required this.id,
    required this.fluids,
    required this.meals,
  }) {
    sortMeals();  // Sort meals when Planner is created
  }

  void sortMeals() {
    meals.sort((a, b) {
      // First, compare by completion status (false comes before true)
      if (a.completed != b.completed) {
        return a.completed ? 1 : -1;
      }
      
      // Parse times into comparable format (assuming HH:mm format)
      try {
        final timeA = _parseTime(a.time);
        final timeB = _parseTime(b.time);
        return timeA.compareTo(timeB);
      } catch (e) {
        // If time parsing fails, fall back to string comparison
        return a.time.compareTo(b.time);
      }
    });
  }

  DateTime _parseTime(String time) {
    // Handle both HH:mm and HH:mm:ss formats
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    
    return DateTime(2000, 1, 1, hour, minute); // Use arbitrary date for time comparison
  }

  factory Planner.fromJson(Map<String, dynamic> json) {
    List<Fluid> fluidsList = [];
    if (json['fluids'] != null) {
      fluidsList = List<Fluid>.from(
        json['fluids'].map((fluid) => Fluid.fromJson(fluid)),
      );
    }

    List<Meal> mealsList = [];
    if (json['meals'] != null) {
      mealsList = List<Meal>.from(
        json['meals'].map((meal) => Meal.fromJson(meal)),
      );
    }

    return Planner(
      id: json['_id'] ?? '',
      fluids: fluidsList,
      meals: mealsList,
    );
  }
}

class Fluid {
  final String id;
  final String type;
  final int amount;

  Fluid({
    required this.id,
    required this.type,
    required this.amount,
  });

  factory Fluid.fromJson(Map<String, dynamic> json) {
    return Fluid(
      id: json['_id'] ?? '',
      type: json['type'] ?? '',
      amount: json['amount'] ?? 0,
    );
  }
}

class Meal {
  final String id;
  final String category;
  final String time;
  final bool completed;
  final List<ProductItem> products;
  final List<RecipeItem> recipes;

  Meal({
    required this.id,
    required this.category,
    required this.time,
    required this.completed,
    required this.products,
    required this.recipes,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    List<ProductItem> productsList = [];
    if (json['products'] != null) {
      productsList = List<ProductItem>.from(
        json['products'].map((product) => ProductItem.fromJson(product)),
      );
    }

    List<RecipeItem> recipesList = [];
    if (json['recipes'] != null) {
      recipesList = List<RecipeItem>.from(
        json['recipes'].map((recipe) => RecipeItem.fromJson(recipe)),
      );
    }

    return Meal(
      id: json['_id'] ?? '',
      category: json['category'] ?? '',
      time: json['time'] ?? '',
      completed: json['completed'] ?? false,
      products: productsList,
      recipes: recipesList,
    );
  }
}

class ProductItem {
  final String id;
  final String productId;
  final double amount;

  ProductItem({
    required this.id,
    required this.productId,
    required this.amount,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['_id'] ?? '',
      productId: json['productId'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}

class RecipeItem {
  final String id;
  final String recipeId;
  final double servings;  // We'll keep this as servings internally but parse from portion

  RecipeItem({
    required this.id,
    required this.recipeId,
    required this.servings,
  });

  factory RecipeItem.fromJson(Map<String, dynamic> json) {
    // Extract portion value and ensure it's a valid double
    double portion = 1.0; // Default to 1 portion
    
    if (json['portion'] != null) {  // Changed from 'servings' to 'portion'
      if (json['portion'] is int) {
        portion = (json['portion'] as int).toDouble();
      } else if (json['portion'] is double) {
        portion = json['portion'] as double;
      } else if (json['portion'] is String) {
        portion = double.tryParse(json['portion']) ?? 1.0;
      }
    }
    
    // Ensure portion is never 0.0
    if (portion <= 0.0) {
      portion = 1.0;
    }
    
    return RecipeItem(
      id: json['_id'] ?? '',
      recipeId: json['recipeId'] ?? '',
      servings: portion,  // Use the portion value as servings
    );
  }
}

class NutritionalSummary {
  final MacroNutrients planned;
  final MacroNutrients consumed;

  NutritionalSummary({
    required this.planned,
    required this.consumed,
  });

  factory NutritionalSummary.fromJson(Map<String, dynamic> json) {
    return NutritionalSummary(
      planned: MacroNutrients.fromJson(json['planned'] ?? {}),
      consumed: MacroNutrients.fromJson(json['consumed'] ?? {}),
    );
  }
}

class MacroNutrients {
  final double calories;
  final double proteins;
  final double fats;
  final double carbs;

  MacroNutrients({
    required this.calories,
    required this.proteins,
    required this.fats,
    required this.carbs,
  });

  factory MacroNutrients.fromJson(Map<String, dynamic> json) {
    return MacroNutrients(
      calories: (json['calories'] ?? 0).toDouble(),
      proteins: (json['proteins'] ?? 0).toDouble(),
      fats: (json['fats'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
    );
  }
} 