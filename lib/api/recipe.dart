class Recipe {
  var id;
  String recipeName;
  int kcalPortion;
  int proteinPortion;
  int fatContentPortion;
  int carbohydratesPortion;
  int prepareTime;
  int difficulty;
  List<Map<String, dynamic>> ingredients;
  String category;
  Map<String, dynamic> photo;
  List<String> author;
  String privacy;
  int likes;
  int saves;
  String preDescription;
  String description;
  String preparation;
  List<String> keywords;
  List likedBy;
  bool isLiked;

  Recipe({
    required this.id,
    required this.recipeName,
    required this.kcalPortion,
    required this.proteinPortion,
    required this.fatContentPortion,
    required this.carbohydratesPortion,
    required this.prepareTime,
    required this.difficulty,
    required this.ingredients,
    required this.category,
    required this.photo,
    required this.author,
    required this.privacy,
    required this.likes,
    required this.saves,
    required this.preDescription,
    required this.description,
    required this.preparation,
    required this.keywords,
    required this.likedBy,
    required this.isLiked,
  });

  factory Recipe.fromJson(Map<String, dynamic> json, [var userId]) {
    try {
      List<dynamic> likedByList = json['likedBy'] ?? [];
      bool liked;
      if(userId == null) {
        liked = false;
      } else{
        liked = likedByList.contains(userId);
      }

      // Handle author field correctly - it's an array of objects
      List<dynamic> rawAuthors = json['author'] ?? [];
      List<String> authorNames = [];
      
      for (var author in rawAuthors) {
        if (author is Map<String, dynamic>) {
          // Extract the username or some identifier from the author object
          String authorName = author['username'] ?? 'Unknown Author';
          authorNames.add(authorName);
        } else if (author is String) {
          // Handle case where author might be a string
          authorNames.add(author);
        }
      }
      
      // Handle ingredients with safer type conversion
      List<Map<String, dynamic>> safeIngredients = [];
      final rawIngredients = json['ingredients'] ?? [];
      
      for (var ingredient in rawIngredients) {
        if (ingredient is Map<String, dynamic>) {
          safeIngredients.add(ingredient);
        }
      }
      
      // Safe conversion for photo field
      Map<String, dynamic> photoData = {};
      if (json['photo'] != null && json['photo'] is Map) {
        photoData = Map<String, dynamic>.from(json['photo']);
      }
      
      // Safe conversion for keywords
      List<String> keywords = [];
      final rawKeywords = json['keyWords'] ?? [];
      
      for (var keyword in rawKeywords) {
        if (keyword is String) {
          keywords.add(keyword);
        }
      }
      
      return Recipe(
        id: json['_id'] ?? '',
        recipeName: json['name'] ?? '',
        kcalPortion: json['kcalPortion'] is int ? json['kcalPortion'] : 0,
        proteinPortion: json['proteinPortion'] is int ? json['proteinPortion'] : 0,
        fatContentPortion: json['fatContentPortion'] is int ? json['fatContentPortion'] : 0,
        carbohydratesPortion: json['carbohydratesPortion'] is int ? json['carbohydratesPortion'] : 0,
        prepareTime: json['prepareTime'] is int ? json['prepareTime'] : 0,
        difficulty: json['difficulty'] is int ? json['difficulty'] : 0,
        ingredients: safeIngredients,
        category: json['category'] is String ? json['category'] : '',
        photo: photoData,
        author: authorNames,
        privacy: json['privacy'] is String ? json['privacy'] : '',
        likes: json['likeQuantity'] is int ? json['likeQuantity'] : 0,
        saves: json['saveQuantity'] is int ? json['saveQuantity'] : 0,
        preDescription: json['preDescription'] is String ? json['preDescription'] : '',
        description: json['description'] is String ? json['description'] : '',
        preparation: json['preparation'] is String ? json['preparation'] : '',
        keywords: keywords,
        likedBy: List.from(likedByList),
        isLiked: liked,
      );
    } catch (e) {
      print('Error in Recipe.fromJson: $e');
      print('Problematic JSON: $json');
      
      // Return a minimal valid Recipe object rather than throwing an exception
      return Recipe(
        id: json['_id'] ?? '',
        recipeName: 'Error loading recipe',
        kcalPortion: 0,
        proteinPortion: 0,
        fatContentPortion: 0,
        carbohydratesPortion: 0,
        prepareTime: 0,
        difficulty: 0,
        ingredients: [],
        category: '',
        photo: {'fileName': ''},
        author: [],
        privacy: 'public',
        likes: 0,
        saves: 0,
        preDescription: '',
        description: 'There was an error loading this recipe.',
        preparation: '',
        keywords: [],
        likedBy: [],
        isLiked: false,
      );
    }
  }
}