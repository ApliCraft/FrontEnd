import 'package:flutter/material.dart';
import '../widgets/bottomNavBar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:decideat/api/api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'storage/search_products.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoragePage extends StatefulWidget {
  const StoragePage({Key? key}) : super(key: key);

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'expiration'; // 'name', 'expiration', 'quantity'
  bool _showExpiringSoon = false;
  bool _isGridView = true; // Added view toggle state
  
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Update category list to match products.dart
  final List<String> _allCategories = [
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

  // List of all categories plus "All" option - replacing with comprehensive list
  List<String> get allCategories => _allCategories;
  
  @override
  void initState() {
    super.initState();
    _fetchStorageData(); // Fetch data when the widget is initialized
  }

  // Function to fetch product details by ID
  Future<Map<String, dynamic>> _fetchProductDetails(String productId) async {
    final String? token = await storage.read(key: 'accessToken');
    
    if (token == null) {
      print('Error: Token is null. Please log in again.');
      return {
        'name': 'Unknown Product',
        'category': 'Unknown',
        'imageUrl': null,
      };
    }
    
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/product/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final productData = json.decode(response.body);
        
        // Construct the proper image URL
        String? imageUrl;
        if (productData['photo'] != null && productData['photo']['filePath'] != null) {
          imageUrl = '$apiUrl/images/${productData['photo']['filePath'].split('/').last}';
        }
        
        return {
          'name': productData['name'] ?? 'Unknown Product',
          'plName': productData['plName'],
          'category': productData['class'] ?? 'Unknown', // Using 'class' as category
          'imageUrl': imageUrl,
          'kcal': productData['kcalPortion'],
          'protein': productData['proteinPortion'],
          'carbs': productData['carbohydratesPortion'],
          'fat': productData['fatContentPortion'],
          'excludedDiets': productData['excludedDiets'],
          'allergens': productData['allergens'],
        };
      } else {
        print('Failed to load product details: ${response.statusCode}');
        return {
          'name': 'Unknown Product',
          'category': 'Unknown',
          'imageUrl': null,
        };
      }
    } catch (e) {
      print('Error fetching product details: $e');
      return {
        'name': 'Unknown Product',
        'category': 'Unknown',
        'imageUrl': null,
      };
    }
  }

  // New method to fetch data from the API
  Future<void> _fetchStorageData() async {
    setState(() {
      _isLoading = true;
    });
    
    final String storageUrl = '$apiUrl/user/storage/get';
    final String? token = await storage.read(key: 'accessToken');

    // Check if the token is null
    if (token == null) {
      print('Error: Token is null. Please log in again.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(storageUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> processedItems = [];
        
        // Process each storage item
        for (var item in data) {
          String productId = item['product'];
          
          // Skip items with invalid product IDs
          if (productId.isEmpty) continue;
          
          // Fetch product details
          final productDetails = await _fetchProductDetails(productId);
          
          processedItems.add({
            'id': item['_id'],
            'product': productId, // Store the product ID directly
            'name': productDetails['name'],
            'plName': productDetails['plName'],
            'category': productDetails['category'],
            'imageUrl': productDetails['imageUrl'],
            'quantity': item['quantity'] ?? 0,
            'unit': item['unit'] ?? 'g',
            'expiration': item['expirationDate'] ?? 'No Expiration',
            'addDate': item['addDate'] ?? DateTime.now().toIso8601String(),
            'kcal': productDetails['kcal'],
            'protein': productDetails['protein'],
            'carbs': productDetails['carbs'],
            'fat': productDetails['fat'],
          });
        }
        
        setState(() {
          _items = processedItems;
          _isLoading = false;
        });
      } else {
        print('Failed to load storage: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching storage data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Filter items based on selected category
  List<Map<String, dynamic>> get filteredItems {
    List<Map<String, dynamic>> result = _items;

    // Apply category filter (if not "All")
    if (_selectedCategory != 'All') {
      result = result.where((item) => 
        item['category'] == _selectedCategory
      ).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((item) =>
        item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (item['plName'] != null && 
         item['plName'].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
      ).toList();
    }

    // Apply expiring soon filter
    if (_showExpiringSoon) {
      final now = DateTime.now();
      result = result.where((item) {
        if (item['expiration'] != null && item['expiration'] != 'No Expiration') {
          try {
            final expirationDate = DateTime.parse(item['expiration']);
            return expirationDate.difference(now).inDays <= 3; // Items expiring in 3 days or less
          } catch (e) {
            return false;
          }
        }
        return false;
      }).toList();
    }

    // Sort the items
    if (_sortBy == 'name') {
      result.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    } else if (_sortBy == 'expiration') {
      result.sort((a, b) {
        try {
          if (a['expiration'] == 'No Expiration') return 1;
          if (b['expiration'] == 'No Expiration') return -1;
          
          final dateA = DateTime.parse(a['expiration']);
          final dateB = DateTime.parse(b['expiration']);
          return dateA.compareTo(dateB);
        } catch (e) {
          return 0;
        }
      });
    } else if (_sortBy == 'quantity') {
      result.sort((a, b) => b['quantity'].compareTo(a['quantity']));
    }

    return result;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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
        child: Column(
          children: [
            // App Bar
            AppBar(
              title: Text(loc.storage, style: const TextStyle(fontWeight: FontWeight.bold)),
              elevation: 0,
              backgroundColor: Colors.green.shade50,
              scrolledUnderElevation: 0,
              actions: [
                // View toggle button
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(_showExpiringSoon ? Icons.warning_amber : Icons.warning_amber_outlined),
                  color: _showExpiringSoon ? Colors.orange : null,
                  onPressed: () {
                    setState(() {
                      _showExpiringSoon = !_showExpiringSoon;
                    });
                  },
                  tooltip: 'Show expiring soon',
                ),
              ],
            ),
            
            // Search bar and filter similar to products.dart
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _buildSearchBar(context),
            ),
            
            // Category selector
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: allCategories.length,
                itemBuilder: (context, index) {
                  final category = allCategories[index];
                  final isActive = _selectedCategory == category;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10, bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Storage items in scrollable container
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _isGridView 
                      ? _buildDenseGridItems(context, loc, isLargeScreen)
                      : _buildListItems(context, loc),
                  ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        child: const Icon(Icons.add),
        backgroundColor: Colors.green,
      ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 3),
    );
  }
  
  // Search bar widget - updated to match products.dart style
  Widget _buildSearchBar(BuildContext context) {
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
        style: const TextStyle(fontSize: 15), // Increased from 14
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: const TextStyle(fontSize: 15), // Increased from 14
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                ),
              IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.grey),
                onPressed: () {
                  _showFilterBottomSheet(context);
                },
                tooltip: 'Filter',
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15), // Increased from 10
        ),
      ),
    );
  }
  
  // New method for dense grid items with more items per row
  Widget _buildDenseGridItems(BuildContext context, AppLocalizations loc, bool isLargeScreen) {
    // Determine number of columns based on screen size
    int crossAxisCount;
    if (MediaQuery.of(context).size.width > 1200) {
      crossAxisCount = 5; // Reduced from 6 for bigger cards
    } else if (MediaQuery.of(context).size.width > 900) {
      crossAxisCount = 4; // Reduced from 5 for bigger cards
    } else if (MediaQuery.of(context).size.width > 600) {
      crossAxisCount = 3; // Reduced from 4 for bigger cards
    } else if (MediaQuery.of(context).size.width > 400) {
      crossAxisCount = 2; // Reduced from 3 for bigger cards
    } else {
      crossAxisCount = 2;
    }
    
    // Handle empty results
    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedCategory == 'All' 
                  ? 'No items found in your storage'
                  : 'No ${_selectedCategory.toLowerCase()} found in your storage',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            // const SizedBox(height: 8),
            // ElevatedButton.icon(
            //   onPressed: () {
            //     _showAddItemDialog(context);
            //   },
            //   icon: const Icon(Icons.add),
            //   label: Text('Add ${_selectedCategory == 'All' ? 'items' : _selectedCategory.toLowerCase()}'),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.green,
            //     foregroundColor: Colors.white,
            //   ),
            // ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12, // Increased from 8
        crossAxisSpacing: 12, // Increased from 8
        childAspectRatio: 0.7, // Adjusted for taller cards
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildCompactStorageItemCard(context, loc, item);
      },
    );
  }
  
  // List view for smaller screens - updated to be more compact
  Widget _buildListItems(BuildContext context, AppLocalizations loc) {
    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedCategory == 'All' 
                  ? 'No items found in your storage'
                  : 'No ${_selectedCategory.toLowerCase()} found in your storage',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            // const SizedBox(height: 8),
            // ElevatedButton.icon(
            //   onPressed: () {
            //     _showAddItemDialog(context);
            //   },
            //   icon: const Icon(Icons.add),
            //   label: Text('Add ${_selectedCategory == 'All' ? 'items' : _selectedCategory.toLowerCase()}'),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.green,
            //     foregroundColor: Colors.white,
            //   ),
            // ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10), // Increased from 8
          child: _buildCompactListItemCard(context, loc, item),
        );
      },
    );
  }
  
  // New more compact card for grid view with larger images and text
  Widget _buildCompactStorageItemCard(BuildContext context, AppLocalizations loc, Map<String, dynamic> item) {
    final String name = item['name'] ?? 'Unknown Product';
    final int quantity = item['quantity'] ?? 0;
    final String expiration = item['expiration'] ?? 'No Expiration';
    final String unit = item['unit'] ?? 'N/A';
    final String category = item['category'] ?? 'Unknown Category';
    
    DateTime? expirationDate;
    bool isExpiringSoon = false;
    bool isExpired = false;
    int daysUntilExpiration = 0;
    String formattedExpiration = 'No Expiration';
    
    try {
      expirationDate = DateTime.parse(expiration);
      final now = DateTime.now();
      
      // Format date as yyyy/mm/dd
      formattedExpiration = '${expirationDate.year}/${expirationDate.month.toString().padLeft(2, '0')}/${expirationDate.day.toString().padLeft(2, '0')}';
      
      // Reset time parts to compare dates only
      final todayDate = DateTime(now.year, now.month, now.day);
      final expirationDateOnly = DateTime(expirationDate.year, expirationDate.month, expirationDate.day);
      
      // Calculate days until expiration
      daysUntilExpiration = expirationDateOnly.difference(todayDate).inDays;
      
      // Item is expired if expiration date is before today
      isExpired = expirationDateOnly.isBefore(todayDate);
      
      // Item is expiring soon if 0-2 days left
      isExpiringSoon = !isExpired && daysUntilExpiration <= 2;
    } catch (e) {
      print('Error parsing date: $e');
      // Keep default values if date parsing fails
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item image with category badge
          Stack(
            children: [
              // Item image - made larger
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: item.containsKey('imageUrl') && item['imageUrl'] != null
                      ? CachedNetworkImage(
                          imageUrl: item['imageUrl'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey.shade400,
                                size: 24,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(
                              Icons.restaurant,
                              color: Colors.grey,
                              size: 30,
                            ),
                          ),
                        ),
                ),
              ),
              // Category badge
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
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
              // Expiration badge - only show for expired or items with 2 or fewer days left
              if (isExpired || isExpiringSoon)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? Colors.red.withOpacity(0.8)
                          : Colors.orange.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isExpired
                          ? 'Expired!'
                          : daysUntilExpiration == 0
                              ? 'Today'
                              : '$daysUntilExpiration ${daysUntilExpiration == 1 ? 'day' : 'days'} left',
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
          
          // Item details
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.shopping_basket, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${loc.quantity}: $quantity $unit',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (expiration != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 14,
                        color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.blue), // Color based on expiration status
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          // Display "Expires: Today" for items expiring today
                          daysUntilExpiration == 0 && !isExpired 
                              ? '${loc.expires}: Today'
                              : '${loc.expires}: $formattedExpiration',
                          style: TextStyle(
                            fontSize: 12,
                            color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : null), // Color text based on expiration status
                            fontWeight: (isExpired || isExpiringSoon) ? FontWeight.bold : FontWeight.normal, // Bold for both expired and expiring soon
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
          
          // Actions
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  color: Colors.blue,
                  onPressed: () {
                    _showEditQuantityDialog(context, item);
                  },
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  color: Colors.red,
                  onPressed: () {
                    final productId = item['product'];
                    if (productId == null || productId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: Product ID is missing')),
                      );
                      return;
                    }
                    _deleteProductFromStorage(productId, name);
                  },
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // New compact horizontal card for list view with larger images and text
  Widget _buildCompactListItemCard(BuildContext context, AppLocalizations loc, Map<String, dynamic> item) {
    final String name = item['name'] ?? 'Unknown Product';
    final int quantity = item['quantity'] ?? 0;
    final String expiration = item['expiration'] ?? 'No Expiration';
    final String unit = item['unit'] ?? 'N/A';
    final String category = item['category'] ?? 'Unknown Category';
    
    DateTime? expirationDate;
    bool isExpiringSoon = false;
    bool isExpired = false;
    int daysUntilExpiration = 0;
    String formattedExpiration = 'No Expiration';
    
    try {
      expirationDate = DateTime.parse(expiration);
      final now = DateTime.now();
      
      // Format date as yyyy/mm/dd
      formattedExpiration = '${expirationDate.year}/${expirationDate.month.toString().padLeft(2, '0')}/${expirationDate.day.toString().padLeft(2, '0')}';
      
      // Reset time parts to compare dates only
      final todayDate = DateTime(now.year, now.month, now.day);
      final expirationDateOnly = DateTime(expirationDate.year, expirationDate.month, expirationDate.day);
      
      // Calculate days until expiration
      daysUntilExpiration = expirationDateOnly.difference(todayDate).inDays;
      
      // Item is expired if expiration date is before today
      isExpired = expirationDateOnly.isBefore(todayDate);
      
      // Item is expiring soon if 0-2 days left
      isExpiringSoon = !isExpired && daysUntilExpiration <= 2;
    } catch (e) {
      print('Error parsing date: $e');
      // Keep default values if date parsing fails
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Item image with category badge - made larger
            Stack(
              children: [
                // Item image
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                  child: SizedBox(
                    height: 100,
                    width: 100,
                    child: item.containsKey('imageUrl') && item['imageUrl'] != null
                        ? CachedNetworkImage(
                            imageUrl: item['imageUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey.shade400,
                                  size: 24,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(
                                Icons.restaurant,
                                color: Colors.grey,
                                size: 30,
                              ),
                            ),
                          ),
                  ),
                ),
                // Category badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
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
                // Expiration badge at bottom left of photo - only show for expired or items with 2 or fewer days left
                if (isExpired || isExpiringSoon)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? Colors.red.withOpacity(0.8)
                            : Colors.orange.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isExpired
                            ? 'Expired!'
                            : daysUntilExpiration == 0
                                ? 'Today'
                                : '$daysUntilExpiration ${daysUntilExpiration == 1 ? 'day' : 'days'} left',
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
            
            // Item details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.shopping_basket, size: 14, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          '${loc.quantity}: $quantity $unit',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    if (expiration != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 14,
                            color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.blue), // Color based on expiration status
                          ),
                          const SizedBox(width: 6),
                          // Change text based on expiration status
                          Text(
                            isExpired 
                                ? 'Expired' 
                                : daysUntilExpiration == 0
                                    ? '${loc.expires}: Today'
                                    : formattedExpiration,
                            style: TextStyle(
                              fontSize: 14,
                              color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : null), // Color text based on expiration status
                              fontWeight: (isExpired || isExpiringSoon) ? FontWeight.bold : FontWeight.normal, // Bold for both expired and expiring soon
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Actions - vertical buttons
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  color: Colors.blue,
                  onPressed: () {
                    _showEditQuantityDialog(context, item);
                  },
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  color: Colors.red,
                  onPressed: () {
                    final productId = item['product'];
                    if (productId == null || productId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: Product ID is missing')),
                      );
                      return;
                    }
                    _deleteProductFromStorage(productId, name);
                  },
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
  
  // Filter bottom sheet
  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
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
                    title: const Text('Expiration Date (Soonest first)'),
                    value: 'expiration',
                    groupValue: _sortBy,
                    onChanged: (value) {
                      setModalState(() {
                        _sortBy = value!;
                      });
                      setState(() {});
                    },
                  ),
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
                    title: const Text('Quantity (Highest first)'),
                    value: 'quantity',
                    groupValue: _sortBy,
                    onChanged: (value) {
                      setModalState(() {
                        _sortBy = value!;
                      });
                      setState(() {});
                    },
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Expiring soon switch
                  SwitchListTile(
                    title: const Text('Show only items expiring soon'),
                    value: _showExpiringSoon,
                    onChanged: (value) {
                      setModalState(() {
                        _showExpiringSoon = value;
                      });
                      setState(() {});
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  // Apply button
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  // Add new item dialog
  void _showAddItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add New Item'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name field
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Quantity field
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  
                  // Date picker
                  Row(
                    children: [
                      const Text('Expiration Date: '),
                      TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                          );
                          if (pickedDate != null) {
                            setDialogState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                        child: Text(
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final quantityText = quantityController.text.trim();
                  
                  if (name.isEmpty || quantityText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill in all fields')),
                    );
                    return;
                  }
                  
                  try {
                    final quantity = int.parse(quantityText);
                    final expirationDate = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                    
                    // Add the new item to _items
                    setState(() {
                      _items.add({
                        'name': name,
                        'quantity': quantity,
                        'expiration': expirationDate,
                      });
                    });
                    
                    Navigator.pop(context);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name added to storage')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid quantity')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      nameController.dispose();
      quantityController.dispose();
    });
  }

  // Add a method to show the product search dialog
  Future<void> _showAddProductDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const SearchProductsDialog(),
    );
    
    if (result != null) {
      await _addProductToStorage(result);
    }
  }
  
  // Method to add a product to the storage via API
  Future<void> _addProductToStorage(Map<String, dynamic> product) async {
    setState(() {
      _isLoading = true;
    });
    
    final String? token = await storage.read(key: 'accessToken');
    
    if (token == null) {
      print('Error: Token is null. Please log in again.');
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication error. Please log in again.')),
      );
      return;
    }
    
    try {
    // put request not post
      final response = await http.put(
        Uri.parse('$apiUrl/user/storage/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'productId': product['productId'],
          'quantity': product['quantity'],
          'unit': product['unit'],
          'expirationDate': product['expiration'],
        }),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        // Successfully added, refresh the storage data
        await _fetchStorageData();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product['name']} added to storage')),
        );
      } else {
        print('Failed to add product: ${response.statusCode} - ${response.body}');
        setState(() {
          _isLoading = false;
        });
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add product: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error adding product to storage: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding product: $e')),
      );
    }
  }

  // Add this new method to delete a product from storage
  Future<void> _deleteProductFromStorage(String productId, String itemName) async {
    // Show confirmation dialog
    final bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to remove "$itemName" from your storage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmDelete) {
      return; // User canceled the deletion
    }
    
    setState(() {
      _isLoading = true;
    });
    
    final String? token = await storage.read(key: 'accessToken');
    
    if (token == null) {
      print('Error: Token is null. Please log in again.');
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication error. Please log in again.')),
      );
      return;
    }
    
    try {
      final response = await http.delete(
        Uri.parse('$apiUrl/user/storage/remove/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        // Successfully deleted, refresh the storage data
        await _fetchStorageData();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$itemName removed from storage')),
        );
      } else {
        print('Failed to delete product: ${response.statusCode} - ${response.body}');
        setState(() {
          _isLoading = false;
        });
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete product: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error deleting product from storage: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting product: $e')),
      );
    }
  }

  // Add this new method to show the edit quantity dialog
  void _showEditQuantityDialog(BuildContext context, Map<String, dynamic> item) {
    final currentQuantity = item['quantity'] as int;
    final name = item['name'] as String;
    final unit = item['unit'] as String;
    final productId = item['product'];
    
    String? quantityText;
    bool isIncreasing = true;

    showDialog<void>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit $name Quantity'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current quantity: $currentQuantity $unit'),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        RadioListTile<bool>(
                          title: const Text('Increase'),
                          value: true,
                          groupValue: isIncreasing,
                          onChanged: (bool? value) {
                            if (value != null) {
                              setState(() => isIncreasing = value);
                            }
                          },
                        ),
                        RadioListTile<bool>(
                          title: const Text('Decrease'),
                          value: false,
                          groupValue: isIncreasing,
                          onChanged: (bool? value) {
                            if (value != null) {
                              setState(() => isIncreasing = value);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) => quantityText = value,
                      decoration: InputDecoration(
                        labelText: 'Amount to ${isIncreasing ? 'add' : 'remove'}',
                        border: const OutlineInputBorder(),
                        suffixText: unit,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (quantityText == null || quantityText!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a quantity')),
                      );
                      return;
                    }

                    final quantity = int.tryParse(quantityText!);
                    if (quantity == null || quantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid quantity')),
                      );
                      return;
                    }

                    if (!isIncreasing && quantity > currentQuantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cannot decrease by more than current quantity')),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    
                    // Schedule the update after the dialog is closed
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateProductQuantity(
                        productId,
                        quantity,
                        isIncreasing ? 'increase' : 'decrease',
                        name,
                      );
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Add this new method to update product quantity
  Future<void> _updateProductQuantity(String productId, int quantity, String type, String itemName) async {
    setState(() {
      _isLoading = true;
    });
    
    final String? token = await storage.read(key: 'accessToken');
    
    if (token == null) {
      print('Error: Token is null. Please log in again.');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication error. Please log in again.')),
      );
      return;
    }
    
    try {
      final response = await http.put(
        Uri.parse('$apiUrl/user/storage/increase-decrease-quantity'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'productId': productId,
          'quantity': quantity,
          'type': type,
        }),
      );
      
      if (response.statusCode == 200) {
        // Successfully updated, refresh the storage data
        await _fetchStorageData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == 'increase'
                ? 'Added $quantity units to $itemName'
                : 'Removed $quantity units from $itemName'
            ),
          ),
        );
      } else {
        print('Failed to update quantity: ${response.statusCode} - ${response.body}');
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update quantity: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error updating quantity: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating quantity: $e')),
      );
    }
  }
}