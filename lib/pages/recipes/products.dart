import 'dart:io';
import 'package:flutter/material.dart';
import '../../widgets/bottomNavBar.dart';
import '../../widgets/navigation_recipes_appbar.dart';
import '../../api/product.dart';
import '../../api/api.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({Key? key}) : super(key: key);

  @override
  _ProductsPageState createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  // Search query variable
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Active category filter
  String _activeCategory = 'All';
  
  // Loading state
  bool _isLoading = false;
  
  // Scroll controller and visibility state
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;
  
  // Sort and filter options
  String _sortBy = 'name'; // Sorting options: 'name', 'calories', 'protein', 'carbs', 'fat'
  bool _showVegetarianOnly = false;
  bool _showVeganOnly = false;
  bool _excludeGluten = false;
  bool _excludeLactose = false;
  bool _excludeNuts = false;
  double _maxCaloriesPerPortion = 500;
  
  // Categories list
  final List<String> categories = [
    'All',
    'Fruits',
    'Vegetables',
    'Cereal products',
    'Dairy',
    'Fish and Seafood',
    'Fluids',
    'Meat',
    'Nuts',
    'Sweets and Snacks'
  ];
  
  // Products list
  List<Product> _products = [];
  
  @override
  void initState() {
    super.initState();
    _loadProductsData();
    
    // Add scroll listener
    _scrollController.addListener(_scrollListener);
  }
  
  // Scroll listener to show/hide header based on scroll direction
  void _scrollListener() {
    final currentPosition = _scrollController.position.pixels;
    
    // Determine scroll direction based on position change
    if (currentPosition > _lastScrollPosition + 5) {
      // Scrolling down by a significant amount
      if (_isHeaderVisible) {
        setState(() {
          _isHeaderVisible = false;
        });
      }
    } else if (currentPosition < _lastScrollPosition - 5) {
      // Scrolling up by a significant amount
      if (!_isHeaderVisible) {
        setState(() {
          _isHeaderVisible = true;
        });
      }
    }
    
    // Update last position
    _lastScrollPosition = currentPosition;
  }
  
  // Load products from the API
  Future<void> _loadProductsData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (_activeCategory == 'All') {
        // Fetch all products by making separate calls for each category
        List<Product> allProducts = [];
        
        // Make parallel API calls for better performance
        final futures = categories.where((cat) => cat != 'All').map((category) => 
          _fetchProductsByCategory(category)
        );
        
        // Wait for all API calls to complete
        final results = await Future.wait(futures);
        
        // Combine results
        for (var products in results) {
          allProducts.addAll(products);
        }
        
        setState(() {
          _products = allProducts;
          _isLoading = false;
        });
      } else {
        // Fetch products for the selected category
        final categoryProducts = await _fetchProductsByCategory(_activeCategory);
        
        setState(() {
          _products = categoryProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle any exceptions that occur during the API call
      print('Exception while fetching products: $e');
      setState(() {
        _products = [];
        _isLoading = false;
      });
    }
  }
  
  // Helper method to fetch products by category
  Future<List<Product>> _fetchProductsByCategory(String category) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/product/filter'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "class": category
        }),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Product.fromJson(json)).toList();
      } else {
        print('Error fetching $category products: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception fetching $category products: $e');
      return [];
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Filtered products based on search and category
  List<Product> get filteredProducts {
    return _products.where((product) {
      // Filter by category
      final categoryMatch = _activeCategory == 'All' || product.category == _activeCategory;
      
      // Filter by search query
      final searchMatch = _searchQuery.isEmpty || 
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (product.plName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      // Filter by diet preferences
      bool dietMatch = true;
      
      if (_showVegetarianOnly) {
        dietMatch = dietMatch && (product.excludedDiets == null || !product.excludedDiets!.contains('Vegetarian'));
      }
      
      if (_showVeganOnly) {
        dietMatch = dietMatch && (product.excludedDiets == null || !product.excludedDiets!.contains('Vegan'));
      }
      
      if (_excludeGluten) {
        dietMatch = dietMatch && (product.allergens == null || !product.allergens!.contains('Gluten'));
      }
      
      if (_excludeLactose) {
        dietMatch = dietMatch && (product.allergens == null || !product.allergens!.contains('Lactose'));
      }
      
      if (_excludeNuts) {
        dietMatch = dietMatch && (product.allergens == null || !product.allergens!.contains('Nuts'));
      }
      
      // Filter by max calories - don't filter if set to max value
      final caloriesMatch = _maxCaloriesPerPortion >= 1000 || product.kcalPortion <= _maxCaloriesPerPortion;
      
      return categoryMatch && searchMatch && dietMatch && caloriesMatch;
    }).toList()..sort((a, b) {
      // Apply sorting
      switch (_sortBy) {
        case 'name':
          return a.name.compareTo(b.name);
        case 'calories':
          return a.kcalPortion.compareTo(b.kcalPortion);
        case 'protein':
          return b.proteinPortion.compareTo(a.proteinPortion);
        case 'carbs':
          return a.carbohydratesPortion.compareTo(b.carbohydratesPortion);
        case 'fat':
          return a.fatContentPortion.compareTo(b.fatContentPortion);
        default:
          return a.name.compareTo(b.name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 800;
    
    return Scaffold(
      appBar: const NavigationRecipesAppBar(currentPage: 'products'),
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
        child: Column(
          children: [
            // Animated header (search bar + category selector)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _isHeaderVisible ? 126 : 0,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: _buildSearchBar(),
                    ),
                    // Category selector
                    _buildCategorySelector(),
                  ],
                ),
              ),
            ),
            // Product grid or loading indicator
            Expanded(
              child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildProductsGrid(isLargeScreen),
                  ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 1),
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.grey),
            onPressed: () {
              _showFilterBottomSheet(context);
            },
            tooltip: 'Filter products',
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
  
  Widget _buildCategorySelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isActive = _activeCategory == category;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeCategory = category;
                // Reload products with the new category filter
                _loadProductsData();
              });
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(0,0,12,4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.black87,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildProductsGrid(bool isLargeScreen) {
    // Determine number of columns based on screen size
    int crossAxisCount;
    if (MediaQuery.of(context).size.width > 1200) {
      crossAxisCount = 5;
    } else if (MediaQuery.of(context).size.width > 800) {
      crossAxisCount = 4;
    } else if (MediaQuery.of(context).size.width > 500) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }
    
    return filteredProducts.isEmpty
        ? const Center(
            child: Text(
              'No products found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          )
        : GridView.builder(
            controller: _scrollController, // Add scroll controller here
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return ProductCard(
                product: product,
                onFavoriteToggle: () {
                  setState(() {
                    product.isFavorite = !product.isFavorite;
                  });
                },
              );
            },
          );
  }

  // Filter bottom sheet
  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sort & Filter',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Sort by options
                    const Text(
                      'Sort by',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Radio buttons for sort options
                    RadioListTile<String>(
                      title: const Text('Name (A-Z)'),
                      value: 'name',
                      groupValue: _sortBy,
                      onChanged: (value) {
                        setModalState(() {
                          _sortBy = value!;
                        });
                        setState(() {});
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Calories (Lowest first)'),
                      value: 'calories',
                      groupValue: _sortBy,
                      onChanged: (value) {
                        setModalState(() {
                          _sortBy = value!;
                        });
                        setState(() {});
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Protein (Highest first)'),
                      value: 'protein',
                      groupValue: _sortBy,
                      onChanged: (value) {
                        setModalState(() {
                          _sortBy = value!;
                        });
                        setState(() {});
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Carbs (Lowest first)'),
                      value: 'carbs',
                      groupValue: _sortBy,
                      onChanged: (value) {
                        setModalState(() {
                          _sortBy = value!;
                        });
                        setState(() {});
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Fat (Lowest first)'),
                      value: 'fat',
                      groupValue: _sortBy,
                      onChanged: (value) {
                        setModalState(() {
                          _sortBy = value!;
                        });
                        setState(() {});
                      },
                    ),
                    
                    const Divider(height: 30),
                    
                    // Diet options
                    const Text(
                      'Dietary Requirements',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    SwitchListTile(
                      title: const Text('Vegetarian-friendly only'),
                      value: _showVegetarianOnly,
                      onChanged: (value) {
                        setModalState(() {
                          _showVegetarianOnly = value;
                        });
                        setState(() {});
                      },
                    ),
                    
                    SwitchListTile(
                      title: const Text('Vegan-friendly only'),
                      value: _showVeganOnly,
                      onChanged: (value) {
                        setModalState(() {
                          _showVeganOnly = value;
                        });
                        setState(() {});
                      },
                    ),
                    
                    const Divider(height: 30),
                    
                    // Allergen options
                    const Text(
                      'Exclude Allergens',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    SwitchListTile(
                      title: const Text('Gluten-free'),
                      value: _excludeGluten,
                      onChanged: (value) {
                        setModalState(() {
                          _excludeGluten = value;
                        });
                        setState(() {});
                      },
                    ),
                    
                    SwitchListTile(
                      title: const Text('Lactose-free'),
                      value: _excludeLactose,
                      onChanged: (value) {
                        setModalState(() {
                          _excludeLactose = value;
                        });
                        setState(() {});
                      },
                    ),
                    
                    SwitchListTile(
                      title: const Text('Nut-free'),
                      value: _excludeNuts,
                      onChanged: (value) {
                        setModalState(() {
                          _excludeNuts = value;
                        });
                        setState(() {});
                      },
                    ),
                    
                    const Divider(height: 30),
                    
                    // Max calories slider
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maximum Calories: ${_maxCaloriesPerPortion >= 1000 ? "Unlimited" : "${_maxCaloriesPerPortion.round()} kcal per 100g"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: _maxCaloriesPerPortion,
                          min: 100,
                          max: 1000,
                          divisions: 18,
                          label: _maxCaloriesPerPortion >= 1000 ? "Unlimited" : "${_maxCaloriesPerPortion.round()} kcal",
                          onChanged: (value) {
                            setModalState(() {
                              _maxCaloriesPerPortion = value;
                            });
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _sortBy = 'name';
                              _showVegetarianOnly = false;
                              _showVeganOnly = false;
                              _excludeGluten = false;
                              _excludeLactose = false;
                              _excludeNuts = false;
                              _maxCaloriesPerPortion = 500;
                            });
                            setState(() {});
                          },
                          child: const Text('Reset'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Apply Filters'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onFavoriteToggle;
  
  const ProductCard({
    Key? key,
    required this.product,
    required this.onFavoriteToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Stack(
            children: [
              // Product image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl.startsWith('http')
                              ? product.imageUrl
                              : '$apiUrl/images/${product.imageUrl}',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(
                              Icons.image,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.image,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                        ),
                ),
              ),
              // Category tag
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    product.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Display excluded diets if any
              if (product.excludedDiets != null && product.excludedDiets!.isNotEmpty)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Not for ${product.excludedDiets!.join(', ')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Product details
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name in English and Polish
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.plName != null && product.plName!.isNotEmpty) ...[
                  Text(
                    product.plName!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                // Nutrition info with icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Calories
                    Column(
                      children: [
                        Text(
                          'Calories',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department, size: 14, color: Colors.deepOrange),
                            const SizedBox(width: 2),
                            Text(
                              '${product.kcalPortion}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Protein
                    Column(
                      children: [
                        Text(
                          'Protein',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fitness_center, size: 14, color: Colors.purple),
                            const SizedBox(width: 2),
                            Text(
                              '${product.proteinPortion}g',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Carbs
                    Column(
                      children: [
                        Text(
                          'Carbs',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.grain, size: 14, color: Colors.amber.shade700),
                            const SizedBox(width: 2),
                            Text(
                              '${product.carbohydratesPortion}g',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Fat
                    Column(
                      children: [
                        Text(
                          'Fat',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.opacity, size: 14, color: Colors.lightBlue),
                            const SizedBox(width: 2),
                            Text(
                              '${product.fatContentPortion}g',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                // Show allergens if any
                if (product.allergens != null && product.allergens!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.warning_amber, size: 14, color: Colors.red),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          'Allergens: ${product.allergens!.join(', ')}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
