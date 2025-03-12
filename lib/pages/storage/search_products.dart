import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../api/product.dart';
import '../../api/api.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchProductsDialog extends StatefulWidget {
  const SearchProductsDialog({Key? key}) : super(key: key);

  @override
  _SearchProductsDialogState createState() => _SearchProductsDialogState();
}

class _SearchProductsDialogState extends State<SearchProductsDialog> {
  String _searchQuery = '';
  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'All';

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

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<Product> allProducts = [];
      
      if (_selectedCategory == 'All') {
        // Load products for each category
        for (final category in categories.where((cat) => cat != 'All')) {
          final products = await _fetchProductsByCategory(category);
          allProducts.addAll(products);
        }
      } else {
        // Load products for the selected category only
        final products = await _fetchProductsByCategory(_selectedCategory);
        allProducts.addAll(products);
      }
      
      setState(() {
        _products = allProducts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading products: $e';
        _isLoading = false;
      });
    }
  }

  // Helper method to fetch products by category
  Future<List<Product>> _fetchProductsByCategory(String category) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/product/filter'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"class": category}),
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

  // Filtered products based on search
  List<Product> get filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((product) => 
      product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (product.plName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: const Text(
                    'Add Product to Storage',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            
            // Category selector
            Container(
              height: 50,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isActive = _selectedCategory == category;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                        // Reload products with the new category filter
                        _loadProducts();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
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
            ),
            
            // Error message if any
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            
            // Products list or loading indicator
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildProductsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    final products = filteredProducts;
    
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty 
                  ? 'No products available in this category'
                  : 'No products matching "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _loadProducts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: InkWell(
            onTap: () async {
              // Show product quantity dialog before returning result
              final result = await _showProductQuantityDialog(product);
              if (result != null) {
                Navigator.pop(context, result);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Product image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: product.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: '$apiUrl/images/${product.imageUrl}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.fastfood, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.fastfood, color: Colors.grey),
                          ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Product details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (product.plName != null && product.plName!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            product.plName!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildNutritionTag(
                              icon: Icons.local_fire_department,
                              value: '${product.kcalPortion} kcal',
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(height: 4),
                            _buildNutritionTag(
                              icon: Icons.category,
                              value: product.category,
                              color: Colors.teal.shade600,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Add icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNutritionTag({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showProductQuantityDialog(Product product) async {
    TextEditingController quantityController = TextEditingController(text: '100');
    TextEditingController unitController = TextEditingController(text: 'g');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7)); // Default expiration: 1 week
    
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Set Product Quantity'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product image if available
                    if (product.imageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 120,
                          height: 80,
                          child: CachedNetworkImage(
                            imageUrl: '$apiUrl/images/${product.imageUrl}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.fastfood, color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Product name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (product.plName != null && product.plName!.isNotEmpty)
                      Text(
                        product.plName!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 24),
                    
                    // Quantity input
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Unit input
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit (g, ml, pcs, etc.)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Expiration date picker
                    ListTile(
                      title: const Text('Expiration Date'),
                      subtitle: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
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
                ElevatedButton(
                  onPressed: () {
                    final quantity = int.tryParse(quantityController.text) ?? 100;
                    final unit = unitController.text.isNotEmpty ? unitController.text : 'g';
                    
                    Navigator.pop(context, {
                      'productId': product.id,
                      'name': product.name,
                      'plName': product.plName,
                      'category': product.category,
                      'imageUrl': product.imageUrl,
                      'quantity': quantity,
                      'unit': unit,
                      'expiration': selectedDate.toIso8601String(),
                      'addDate': DateTime.now().toIso8601String(),
                      'kcal': product.kcalPortion,
                      'protein': product.proteinPortion,
                      'carbs': product.carbohydratesPortion,
                      'fat': product.fatContentPortion,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add to Storage'),
                ),
              ],
            );
          },
        );
      },
    );
  }
} 