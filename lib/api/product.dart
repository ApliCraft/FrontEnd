class Product {
  final String id;
  final String name;
  final String? plName;
  final String imageUrl;
  final String category;
  final int kcalPortion;
  final double proteinPortion;
  final double carbohydratesPortion;
  final double fatContentPortion;
  final List<String>? excludedDiets;
  final List<String>? allergens;
  bool isFavorite;
  
  Product({
    required this.id,
    required this.name,
    this.plName,
    required this.imageUrl,
    required this.category,
    required this.kcalPortion,
    required this.proteinPortion,
    required this.carbohydratesPortion,
    required this.fatContentPortion,
    this.excludedDiets,
    this.allergens,
    this.isFavorite = false,
  });
  
  // Factory constructor to create a Product from API JSON
  factory Product.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse int
    int safeParseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        try {
          return int.parse(value);
        } catch (e) {
          return 0;
        }
      }
      return 0;
    }
    
    // Helper function to safely parse double
    double safeParseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          return 0.0;
        }
      }
      return 0.0;
    }
    
    return Product(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      plName: json['plName']?.toString(),
      imageUrl: json['photo'] != null ? (json['photo']['fileName']?.toString() ?? '') : '',
      category: json['class']?.toString() ?? '',
      kcalPortion: safeParseInt(json['kcalPortion']),
      proteinPortion: safeParseDouble(json['proteinPortion']),
      carbohydratesPortion: safeParseDouble(json['carbohydratesPortion']),
      fatContentPortion: safeParseDouble(json['fatContentPortion']),
      excludedDiets: json['excludedDiets'] != null 
          ? List<String>.from(json['excludedDiets'].map((item) => item.toString()))
          : [],
      allergens: json['allergens'] != null 
          ? List<String>.from(json['allergens'].map((item) => item.toString()))
          : [],
    );
  }
}
