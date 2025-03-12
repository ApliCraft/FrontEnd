import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:decideat/models/shopping_list.dart';
import 'package:decideat/services/shopping_list_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:decideat/api/product.dart';
import 'package:decideat/api/api.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Extension method to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    return isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
  }
}

class ShoppingListDetailPage extends StatefulWidget {
  final ShoppingList shoppingList;

  const ShoppingListDetailPage({Key? key, required this.shoppingList}) : super(key: key);

  @override
  _ShoppingListDetailPageState createState() => _ShoppingListDetailPageState();
}

class _ShoppingListDetailPageState extends State<ShoppingListDetailPage> with SingleTickerProviderStateMixin {
  late ShoppingList _shoppingList;
  bool _isEditing = false;
  bool _isSearching = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  List<Product> _searchResults = [];
  bool _isLoading = false;
  TabController? _tabController;
  
  // Categories for products - matching those used in your app
  final List<String> _categories = [
    'Fruits',
    'Vegetables',
    'Cereal products',
    'Dairy',
    'Fish and Seafood',
    'Fluids',
    'Meat',
    'Nuts',
    'Sweets and Snacks',
    'Other'
  ];
  
  // Default unit for products
  final String _defaultUnit = 'pcs';

  List<Product> _products = [];
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    _shoppingList = widget.shoppingList;
    _nameController.text = _shoppingList.name;
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _toggleItemCheck(int index) {
    setState(() {
      _shoppingList.items[index].checked = !_shoppingList.items[index].checked;
      ShoppingListService.saveList(_shoppingList);
    });
  }

  void _saveList() async {
    if (_isEditing) {
      setState(() {
        _shoppingList.name = _nameController.text.trim();
        _isEditing = false;
      });
    }
    
    final result = await ShoppingListService.saveList(_shoppingList);
    if (result) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('List saved successfully')),
      );
    }
  }

  void _shareList() {
    final items = _shoppingList.items;
    final formatter = DateFormat('yyyy-MM-dd');
    final date = formatter.format(_shoppingList.createdAt);
    
    String shareText = '${_shoppingList.name} (${date}):\n\n';
    
    // Group items by category for better readability
    Map<String, List<ShoppingListItem>> itemsByCategory = {};
    
    for (var item in items) {
      if (!itemsByCategory.containsKey(item.category)) {
        itemsByCategory[item.category] = [];
      }
      itemsByCategory[item.category]!.add(item);
    }
    
    // Build the text with categories
    itemsByCategory.forEach((category, categoryItems) {
      shareText += '${category}:\n';
      
      for (var item in categoryItems) {
        shareText += '${item.checked ? '☑' : '☐'} ${item.name} (${item.quantity} ${item.unit})\n';
      }
      
      shareText += '\n';
    });
    
    Share.share(shareText);
  }

  void _printList() {
    // Here you would implement print functionality
    // For now, show a message that it's not implemented
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Print functionality coming soon!')),
    );
  }

  Future<void> _loadInitialProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      List<Product> allProducts = [];
      
      // Load products for each category
      for (final category in _categories) {
        try {
          final response = await http.post(
            Uri.parse('$apiUrl/product/filter'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "class": category,
            }),
          );
          
          if (response.statusCode == 200) {
            final List<dynamic> data = json.decode(response.body);
            final products = data.map((json) => Product.fromJson(json)).toList();
            allProducts.addAll(products);
          }
        } catch (e) {
          print('Error fetching $category products: $e');
        }
      }
      
      setState(() {
        _products = allProducts;
        _searchResults = allProducts;
        _isLoadingProducts = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = _products;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // First try exact category match
      final categoryMatch = _categories.firstWhere(
        (cat) => cat.toLowerCase().contains(query.toLowerCase()),
        orElse: () => '',
      );

      if (categoryMatch.isNotEmpty) {
        // If query matches a category, filter existing products by that category
        setState(() {
          _searchResults = _products.where((product) => 
            product.category.toLowerCase() == categoryMatch.toLowerCase()
          ).toList();
          _isLoading = false;
        });
        return;
      }

      // If no category match, search by name in existing products
      setState(() {
        _searchResults = _products.where((product) =>
          product.name.toLowerCase().contains(query.toLowerCase()) ||
          (product.plName?.toLowerCase().contains(query.toLowerCase()) ?? false)
        ).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching products: $e');
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  void _showAddItemModal() {
    _searchController.clear();
    _searchResults = [];
    _isSearching = false;
    
    final TextEditingController customNameController = TextEditingController();
    final TextEditingController quantityController = TextEditingController(text: '1');
    String selectedUnit = _defaultUnit;
    String selectedCategory = 'Other';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Add Item to Shopping List',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                
                // Tab bar
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.green,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.green,
                  tabs: const [
                    Tab(text: 'Search Products'),
                    Tab(text: 'Custom Item'),
                  ],
                ),
                
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Search products tab
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search for products',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setModalState(() {
                                            _searchResults = [];
                                          });
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onChanged: (value) {
                                if (value.length >= 2) {
                                  _searchProducts(value);
                                } else if (value.isEmpty) {
                                  setModalState(() {
                                    _searchResults = [];
                                  });
                                }
                              },
                            ),
                          ),
                          
                          // Search results
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : _searchResults.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.search_off,
                                              size: 64,
                                              color: Colors.grey.shade300,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              _searchController.text.isEmpty
                                                  ? 'Search for products to add'
                                                  : 'No products found',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _searchResults.length,
                                        itemBuilder: (context, index) {
                                          final product = _searchResults[index];
                                          return ListTile(
                                            title: Text(product.name),
                                            subtitle: Text('${product.category}'),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                              onPressed: () {
                                                // Show quantity selector
                                                _showQuantitySelector(product);
                                              },
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ],
                      ),
                      
                      // Custom item tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add Custom Item',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: customNameController,
                              decoration: InputDecoration(
                                labelText: 'Item Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              autofocus: false,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: quantityController,
                                    decoration: InputDecoration(
                                      labelText: 'Quantity',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedUnit,
                                      items: ['pcs', 'g', 'kg', 'ml', 'l', 'tbsp', 'tsp']
                                          .map((unit) => DropdownMenuItem(
                                                value: unit,
                                                child: Text(unit),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        setModalState(() {
                                          selectedUnit = value!;
                                        });
                                      },
                                      hint: const Text('Unit'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              items: _categories
                                  .map((category) => DropdownMenuItem(
                                        value: category,
                                        child: Text(category),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setModalState(() {
                                  selectedCategory = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (customNameController.text.trim().isNotEmpty) {
                                    setState(() {
                                      _shoppingList.items.add(ShoppingListItem(
                                        name: customNameController.text.trim(),
                                        quantity: double.tryParse(quantityController.text) ?? 1,
                                        unit: selectedUnit,
                                        category: selectedCategory,
                                      ));
                                      // Save the changes
                                      ShoppingListService.saveList(_shoppingList);
                                    });
                                    Navigator.pop(context);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Item name is required')),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Add to List'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showQuantitySelector(Product product) {
    final TextEditingController quantityController = TextEditingController(text: '1');
    // Since the Product class doesn't have a unit property, use the default
    String selectedUnit = _defaultUnit;
    
    // Determine category based on product type if possible
    String category = 'Other';
    if (product.category.isNotEmpty) {
      category = _mapProductCategoryToShoppingCategory(product.category);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedUnit,
                  items: ['pcs', 'g', 'kg', 'ml', 'l', 'tbsp', 'tsp']
                      .map((unit) => DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedUnit = value!;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _shoppingList.items.add(ShoppingListItem(
                  name: product.name,
                  quantity: double.tryParse(quantityController.text) ?? 1,
                  unit: selectedUnit,
                  category: category,
                ));
                // Save the changes
                ShoppingListService.saveList(_shoppingList);
              });
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close bottom sheet
            },
            child: const Text('Add'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to map product category to shopping category
  String _mapProductCategoryToShoppingCategory(String productCategory) {
    final lowercaseCategory = productCategory.toLowerCase();
    
    if (lowercaseCategory.contains('dairy') || lowercaseCategory.contains('milk')) {
      return 'Dairy';
    } else if (lowercaseCategory.contains('meat') || lowercaseCategory.contains('poultry')) {
      return 'Meat';
    } else if (lowercaseCategory.contains('fish') || lowercaseCategory.contains('seafood')) {
      return 'Fish and Seafood';
    } else if (lowercaseCategory.contains('fruit')) {
      return 'Fruits';
    } else if (lowercaseCategory.contains('vegetable')) {
      return 'Vegetables';
    } else if (lowercaseCategory.contains('bread') || lowercaseCategory.contains('cereal')
        || lowercaseCategory.contains('pasta') || lowercaseCategory.contains('rice')) {
      return 'Cereal products';
    } else if (lowercaseCategory.contains('fluid') || lowercaseCategory.contains('drink')
        || lowercaseCategory.contains('water') || lowercaseCategory.contains('oil')) {
      return 'Fluids';
    } else if (lowercaseCategory.contains('nut')) {
      return 'Nuts';
    } else if (lowercaseCategory.contains('sweet') || lowercaseCategory.contains('snack')
        || lowercaseCategory.contains('dessert') || lowercaseCategory.contains('candy')) {
      return 'Sweets and Snacks';
    } else {
      return 'Other';
    }
  }

  // Helper method to map legacy category names to new ones if needed
  String _mapLegacyCategory(String category) {
    switch (category.toLowerCase()) {
      case 'bakery':
        return 'Cereal products';
      case 'grains':
        return 'Cereal products';
      case 'oils':
        return 'Fluids';
      case 'spices':
        return 'Other';
      default:
        // Check if the category exists in our new list
        if (_categories.contains(category)) {
          return category;
        }
        // If category doesn't match our new list, capitalize first letter
        if (_categories.contains(category.capitalize())) {
          return category.capitalize();
        }
        return 'Other';
    }
  }

  void _removeItem(int index) {
    final item = _shoppingList.items[index];
    setState(() {
      _shoppingList.items.removeAt(index);
      // Save the changes
      ShoppingListService.saveList(_shoppingList);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _shoppingList.items.insert(index, item);
              // Save the changes
              ShoppingListService.saveList(_shoppingList);
            });
          },
        ),
      ),
    );
  }
  
  // Edit existing item
  void _showEditItemDialog(int index) {
    final item = _shoppingList.items[index];
    final TextEditingController nameController = TextEditingController(text: item.name);
    final TextEditingController quantityController = TextEditingController(text: item.quantity.toString());
    String selectedUnit = item.unit;
    String selectedCategory = item.category;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: selectedUnit,
                    items: ['pcs', 'g', 'kg', 'ml', 'l', 'tbsp', 'tsp']
                        .map((unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedUnit = value!;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                ),
                items: _categories
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value!;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  _shoppingList.items[index] = ShoppingListItem(
                    id: item.id,
                    name: nameController.text.trim(),
                    quantity: double.tryParse(quantityController.text) ?? item.quantity,
                    unit: selectedUnit,
                    category: selectedCategory,
                    checked: item.checked,
                  );
                  // Save the changes
                  ShoppingListService.saveList(_shoppingList);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final completionPercentage = _shoppingList.completionPercentage;
    
    // Group items by category and map any legacy categories
    Map<String, List<ShoppingListItem>> itemsByCategory = {};
    
    for (var item in _shoppingList.items) {
      // Map legacy categories to new categories
      String mappedCategory = _mapLegacyCategory(item.category);
      
      if (!itemsByCategory.containsKey(mappedCategory)) {
        itemsByCategory[mappedCategory] = [];
      }
      itemsByCategory[mappedCategory]!.add(item);
    }
    
    return Scaffold(
      appBar: AppBar(
        title: _isEditing
            ? TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'List name',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
              )
            : Text(_shoppingList.name),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
              
              if (!_isEditing) {
                _saveList();
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'save') {
                _saveList();
              } else if (value == 'share') {
                _shareList();
              } else if (value == 'print') {
                _printList();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('Save'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('Share'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Text('Print'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: completionPercentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              completionPercentage == 1.0 ? Colors.green : Colors.blue,
            ),
          ),
          
          // Progress stats
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _shoppingList.items.isEmpty 
                      ? 'No items in list' 
                      : '${_shoppingList.checkedCount} of ${_shoppingList.items.length} items checked',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '${(completionPercentage * 100).round()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: completionPercentage == 1.0 ? Colors.green : Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          // List items grouped by category
          Expanded(
            child: _shoppingList.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your shopping list is empty',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddItemModal,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Items'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: itemsByCategory.length,
                    itemBuilder: (context, categoryIndex) {
                      final category = itemsByCategory.keys.elementAt(categoryIndex);
                      final categoryItems = itemsByCategory[category]!;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: categoryItems.length,
                            itemBuilder: (context, index) {
                              final item = categoryItems[index];
                              final itemIndex = _shoppingList.items.indexOf(item);
                              
                              return Dismissible(
                                key: Key(item.id),
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                direction: DismissDirection.endToStart,
                                onDismissed: (direction) => _removeItem(itemIndex),
                                child: CheckboxListTile(
                                  value: item.checked,
                                  onChanged: (_) => _toggleItemCheck(itemIndex),
                                  title: Text(
                                    item.name,
                                    style: TextStyle(
                                      decoration: item.checked ? TextDecoration.lineThrough : null,
                                      color: item.checked ? Colors.grey : Colors.black,
                                    ),
                                  ),
                                  subtitle: Text('${item.quantity} ${item.unit}'),
                                  secondary: IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditItemDialog(itemIndex),
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemModal,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}