import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ExampleSearchDialog extends StatefulWidget {
  final String mealType;
  final DateTime selectedDate;

  const ExampleSearchDialog({
    Key? key,
    required this.mealType,
    required this.selectedDate,
  }) : super(key: key);

  @override
  _ExampleSearchDialogState createState() => _ExampleSearchDialogState();
}

class _ExampleSearchDialogState extends State<ExampleSearchDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement API calls to load recipes and products
      // Example API structure:
      // final recipesResponse = await http.get('$apiUrl/recipes?category=${widget.mealType}');
      // final productsResponse = await http.get('$apiUrl/products');
      
      setState(() {
        _recipes = [];
        _products = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredRecipes {
    if (_searchQuery.isEmpty) {
      return _recipes;
    }
    return _recipes.where((recipe) =>
      recipe['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
      recipe['description'].toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }
    return _products.where((product) =>
      product['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (product['plName']?.toLowerCase() ?? '').contains(_searchQuery.toLowerCase())
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
                  child: Text(
                    'Add to ${widget.mealType}',
                    style: const TextStyle(
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
            
            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Recipes'),
                Tab(text: 'Products'),
              ],
            ),
            
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
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
            
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Recipes tab
                  _buildRecipesList(),
                  
                  // Products tab
                  _buildProductsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipesList() {
    final recipes = _filteredRecipes;
    
    if (recipes.isEmpty) {
      return const Center(
        child: Text(
          'No recipes found for this meal type.',
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () {
              Navigator.pop(context, {
                'type': 'recipe',
                'id': recipe['id'],
                'name': recipe['name'],
                'calories': recipe['calories'],
                'protein': recipe['protein'],
                'carbs': recipe['carbs'],
                'fat': recipe['fat'],
                'category': recipe['category'],
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Recipe placeholder image
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.restaurant, color: Colors.grey.shade400, size: 40),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Recipe details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipe['description'],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.local_fire_department, size: 14, color: Colors.deepOrange),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe['calories']} kcal',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.access_time, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe['prepTime']} min',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Add icon
                  const Icon(Icons.add_circle_outline, color: Colors.green),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsList() {
    final products = _filteredProducts;
    
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'No products found matching your search.',
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () {
              Navigator.pop(context, {
                'type': 'product',
                'id': product['id'],
                'name': product['name'],
                'calories': product['calories'],
                'protein': product['protein'],
                'carbs': product['carbs'],
                'fat': product['fat'],
                'category': product['category'],
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Product placeholder image
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.fastfood, color: Colors.grey.shade400, size: 40),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Product details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          product['plName'],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.local_fire_department, size: 14, color: Colors.deepOrange),
                            const SizedBox(width: 4),
                            Text(
                              '${product['calories']} kcal',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.category, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              product['category'],
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Add icon
                  const Icon(Icons.add_circle_outline, color: Colors.green),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}