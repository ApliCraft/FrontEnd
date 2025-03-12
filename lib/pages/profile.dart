import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/bottomNavBar.dart';
import '../widgets/navigationProfileAppBar.dart';
import 'profile/edit_profile.dart';
import 'package:share_plus/share_plus.dart';
import 'package:decideat/api/api.dart';
import 'package:http/http.dart' as http;
import 'package:decideat/widgets/loading_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Custom scroll behavior that allows mouse, touch, and trackpad drag events.
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class ProfilePage extends StatefulWidget {
  final String? id;
  const ProfilePage({Key? key, this.id}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();

  get userId => id;
}

class _ProfilePageState extends State<ProfilePage> {
  // Flag to control parent's vertical scrolling.
  bool _disableParentScroll = false;
  final ScrollController _verticalScrollController = ScrollController();
  String? userId;
  late String userUrl;
  String username = '';
  String _avatarLink = '$apiUrl/images/default_avatar.png';
  List roles = [];
  String description = '';
  DateTime signInDate = DateTime.utc(0, 0, 0);
  int friendsCount = 0;
  int likedRecipesCount = 0;
  
  // Add new state variables for last eaten meals
  List<Map<String, dynamic>> lastEatenMeals = [];
  bool _isLoadingMeals = false;

  bool _isLoading = true; // Loading flag

  @override
  void initState() {
    super.initState();
    RefreshTokenIfExpired();
    _getProfileData();
  }

  Future<void> _getProfileData() async {
    userId = widget.userId ?? await storage.read(key: 'userId');
    userUrl = '$apiUrl/user/$userId';
    final response =
        await http.get(Uri.parse(userUrl), headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        print(data['signInDate']);
        signInDate = DateTime.parse(data['signInDate'] ?? '1970-01-01');
        print(signInDate);
        username = data['username'] ?? '';
        _avatarLink =
            '$apiUrl/images/${((data['avatarLink'] ?? '').split('/').last) == '' ? "default_avatar.png" : (data['avatarLink'] as String).split('/').last}';
        roles = data['roles'] ?? []; // Provide an empty list if null.
        description = data['description'] ?? '';
        friendsCount = data['friendsList'] ?? 0;
        likedRecipesCount = data['likedRecipes'] ?? 0;
        _isLoading = false;
      });
      
      // Fetch last eaten meals after profile data is loaded
      _fetchLastEatenMeals();
    } else {
      print('Failed to load profile data');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLastEatenMeals() async {
    setState(() {
      _isLoadingMeals = true;
    });
    
    try {
      await RefreshTokenIfExpired();
      final accessToken = await storage.read(key: 'accessToken');
      final targetId = widget.id ?? userId;
      
      // Get last meals IDs
      final lastMealsResponse = await http.get(
        Uri.parse('$apiUrl/user/planner/last-meals/$targetId'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
        },
      );
      
      print('Last meals response status: ${lastMealsResponse.statusCode}');
      
      // Handling 404 or "planner not found" responses gracefully
      if (lastMealsResponse.statusCode == 404 || 
          lastMealsResponse.body.toLowerCase().contains("planner not found")) {
        print('No planner found for user: $targetId');
        setState(() {
          lastEatenMeals = [];
          _isLoadingMeals = false;
        });
        return;
      }
      
      if (lastMealsResponse.statusCode == 200) {
        final mealIds = jsonDecode(lastMealsResponse.body) as List;
        
        // If there are no meal IDs, handle as empty state
        if (mealIds.isEmpty) {
          setState(() {
            lastEatenMeals = [];
            _isLoadingMeals = false;
          });
          return;
        }
        
        // For each meal ID, fetch the meal details
        List<Map<String, dynamic>> meals = [];
        
        for (var mealId in mealIds) {
          print('Fetching meal details for ID: $mealId');
          final mealResponse = await http.get(
            Uri.parse('$apiUrl/user/planner/meal/$mealId'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $accessToken',
            },
          );
          
          // Skip meals that can't be fetched instead of failing the entire process
          if (mealResponse.statusCode != 200) {
            print('Could not fetch meal details for ID: $mealId, Status: ${mealResponse.statusCode}');
            continue;
          }
          
          final mealData = jsonDecode(mealResponse.body);
          print('Successfully fetched meal: ${mealData['category']} at ${mealData['time']}');
          
          // Process products
          for (var product in mealData['products']) {
            try {
              final productDetails = await _fetchProductDetails(product['productId']);
              String photoUrl = '';
              if (productDetails['photo'] != null && productDetails['photo']['fileName'] != null) {
                photoUrl = '$apiUrl/images/${productDetails['photo']['fileName']}';
              }
              
              meals.add({
                'id': mealId,
                'name': productDetails['name'] ?? 'Unknown Product',
                'photoUrl': photoUrl,
                'category': mealData['category'] ?? '',
                'time': mealData['time'] ?? '',
                'completed': mealData['completed'] ?? false,
                'isProduct': true,
                'date': DateTime.now().toString().split(' ')[0], // Just use today's date
              });
            } catch (e) {
              print('Error fetching product details: $e');
              // Add with default values to ensure we show something
              meals.add({
                'id': mealId,
                'name': 'Product',
                'photoUrl': '',
                'category': mealData['category'] ?? '',
                'time': mealData['time'] ?? '',
                'completed': mealData['completed'] ?? false,
                'isProduct': true,
                'date': DateTime.now().toString().split(' ')[0],
              });
            }
          }
          
          // Process recipes
          for (var recipe in mealData['recipes']) {
            try {
              final recipeDetails = await _fetchRecipeDetails(recipe['recipeId']);
              String photoUrl = '';
              if (recipeDetails['photo'] != null && recipeDetails['photo']['fileName'] != null) {
                photoUrl = '$apiUrl/images/${recipeDetails['photo']['fileName']}';
              }
              
              meals.add({
                'id': mealId,
                'name': recipeDetails['name'] ?? 'Unknown Recipe',
                'photoUrl': photoUrl,
                'category': mealData['category'] ?? '',
                'time': mealData['time'] ?? '',
                'completed': mealData['completed'] ?? false,
                'isProduct': false,
                'date': DateTime.now().toString().split(' ')[0],
              });
            } catch (e) {
              print('Error fetching recipe details: $e');
              // Add with default values to ensure we show something
              meals.add({
                'id': mealId,
                'name': 'Recipe',
                'photoUrl': '',
                'category': mealData['category'] ?? '',
                'time': mealData['time'] ?? '',
                'completed': mealData['completed'] ?? false,
                'isProduct': false,
                'date': DateTime.now().toString().split(' ')[0],
              });
            }
          }
        }
        
        // Sort meals by time
        meals.sort((a, b) {
          final timeA = a['time'] ?? '';
          final timeB = b['time'] ?? '';
          return timeA.compareTo(timeB);
        });
        
        setState(() {
          lastEatenMeals = meals;
          _isLoadingMeals = false;
        });
      } else {
        print('Failed to fetch last eaten meals: ${lastMealsResponse.statusCode}');
        setState(() {
          lastEatenMeals = [];
          _isLoadingMeals = false;
        });
      }
    } catch (e) {
      print('Error in _fetchLastEatenMeals: $e');
      setState(() {
        lastEatenMeals = [];
        _isLoadingMeals = false;
      });
    }
  }
  
  Future<Map<String, dynamic>> _fetchProductDetails(String productId) async {
    try {
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
      } else if (response.statusCode == 404) {
        // Handle not found product gracefully
        print('Product not found: $productId');
        return {
          'name': 'Product',
          'photo': null,
        };
      } else {
        print('Error fetching product: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to load product details');
      }
    } catch (e) {
      print('Exception in _fetchProductDetails: $e');
      // Return a default object instead of throwing
      return {
        'name': 'Product',
        'photo': null,
      };
    }
  }
  
  Future<Map<String, dynamic>> _fetchRecipeDetails(String recipeId) async {
    try {
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
      } else if (response.statusCode == 404) {
        // Handle not found recipe gracefully
        print('Recipe not found: $recipeId');
        return {
          'name': 'Recipe',
          'photo': null,
        };
      } else {
        print('Error fetching recipe: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to load recipe details');
      }
    } catch (e) {
      print('Exception in _fetchRecipeDetails: $e');
      // Return a default object instead of throwing
      return {
        'name': 'Recipe',
        'photo': null,
      };
    }
  }

  Route _createRouteToEditProfile() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const EditProfilePage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDishCard(Map<String, dynamic> meal) {
    final String dishName = meal['name'] ?? 'Unknown';
    final String imageUrl = meal['photoUrl'] ?? '';
    final String category = _formatMealCategory(meal['category'] ?? '');
    final String time = meal['time'] ?? '';
    
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            print('Error loading image: $error');
                            return Image.asset(
                              'assets/default_avatar.png',
                              fit: BoxFit.cover,
                            );
                          },
                        )
                      : Image.asset(
                          'assets/default_avatar.png',
                          fit: BoxFit.cover,
                        ),
                ),
                // Category badge in top-left corner
                if (category.isNotEmpty)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  dishName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Helper to format meal category
  String _formatMealCategory(String category) {
    if (category.isEmpty) return '';
    return category.substring(0, 1).toUpperCase() + category.substring(1);
  }

  Widget _buildDishList() {
    final ScrollController dishScrollController = ScrollController();
    
    // Use a more elegant loading indicator that preserves space
    if (_isLoadingMeals && lastEatenMeals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 30, 
              height: 30, 
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 8),
            Text(
              "Loading meals...",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    if (lastEatenMeals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_food,
              size: 28,
              color: Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              "No recent meals found",
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        VerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer(),
          (VerticalDragGestureRecognizer instance) {
            instance.onUpdate = (DragUpdateDetails details) {
              // Scroll horizontally using vertical drag delta.
              final newOffset = dishScrollController.offset + details.delta.dy;
              if (dishScrollController.hasClients) {
                dishScrollController.jumpTo(newOffset);
              }
            };
            // Consume the gesture.
            instance.onStart = (_) {};
            instance.onEnd = (_) {};
          },
        ),
      },
      behavior: HitTestBehavior.opaque,
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            final newOffset =
                dishScrollController.offset + pointerSignal.scrollDelta.dy;
            if (dishScrollController.hasClients) {
              dishScrollController.jumpTo(newOffset);
            }
          }
        },
        child: NotificationListener<ScrollNotification>(
          // Absorb horizontal scroll notifications.
          onNotification: (notification) => true,
          child: ScrollConfiguration(
            behavior: MyCustomScrollBehavior(),
            child: ListView.builder(
              controller: dishScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: lastEatenMeals.length,
              itemBuilder: (context, index) {
                final meal = lastEatenMeals[index];
                return _buildDishCard(meal);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: const NavigationProfileAppBar(currentPage: 'profile'),
      body: !_isLoading
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade50,
                    const Color.fromARGB(0, 255, 255, 255)
                  ],
                  // colors: [const Color.fromARGB(255, 0, 26, 2), const Color.fromARGB(0, 0, 0, 0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  physics: _disableParentScroll
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar, Username, Share, and Edit Profile buttons
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(_avatarLink),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 8.0),
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Share.share(
                                            '${loc.shareProfile('username')} $websiteUrl/user/$userId',
                                          );
                                        },
                                        icon: const Icon(Icons.share),
                                        label: Text(loc.share),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    userId != widget.userId
                                        ? Container(
                                            margin:
                                                const EdgeInsets.only(top: 8.0),
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.push(context,
                                                    _createRouteToEditProfile());
                                              },
                                              icon: const Icon(Icons.edit),
                                              label: Text(loc.editProfile),
                                            ),
                                          )
                                        : Container(
                                            margin:
                                                const EdgeInsets.only(top: 8.0),
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                print('Follow button pressed');
                                              },
                                              icon: const Icon(Icons.person_add),
                                              label: Text(loc.follow),
                                            ),
                                          ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // User description
                      Text(
                        description == ''
                            ? loc.profileDescription
                            : description,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 24),
                      // Statistics: Recipes Count, Friends Count, Date of Join
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStat(loc.recipes, likedRecipesCount.toString()),
                          _buildStat(loc.friends, friendsCount.toString()),
                          _buildStat(
                              loc.joined,
                              signInDate
                                  .toString()
                                  .split(' ')[0]
                                  .replaceAll('-', '/')),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Last eaten dishes title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc.lastEatenDishes,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          _isLoadingMeals 
                            ? const SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2)
                              )
                            : IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _fetchLastEatenMeals,
                                tooltip: 'Refresh meals',
                              ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Wrap the dish list in a MouseRegion to disable parent's vertical scroll
                      MouseRegion(
                        onEnter: (_) {
                          setState(() {
                            _disableParentScroll = true;
                          });
                        },
                        onExit: (_) {
                          setState(() {
                            _disableParentScroll = false;
                          });
                        },
                        child: SizedBox(
                          height: 150,
                          child: _buildDishList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            )
          : loading(),
      bottomNavigationBar: const BottomNavBar(initialIndex: 4),
    );
  }
}
