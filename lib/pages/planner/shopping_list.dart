import 'package:flutter/material.dart';
import 'package:decideat/widgets/navigationPlannerAppBar.dart';
import 'package:decideat/widgets/bottomNavBar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/models/shopping_list.dart';
import 'package:decideat/services/shopping_list_service.dart';
import 'package:decideat/pages/planner/shopping_list_detail.dart';
import 'package:intl/intl.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({Key? key}) : super(key: key);
  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  List<ShoppingList> _shoppingLists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShoppingLists();
  }

  Future<void> _loadShoppingLists() async {
    setState(() {
      _isLoading = true;
    });
    
    final lists = await ShoppingListService.getAllLists();
    
    setState(() {
      _shoppingLists = lists;
      _isLoading = false;
    });
  }

  void _showGenerateDialog() {
    final TextEditingController nameController = TextEditingController(
      text: 'Weekly Meal Plan - ${DateFormat('MMM d').format(DateTime.now())}',
    );
    
    DateTime startDate = DateTime.now();
    DateTime endDate = startDate.add(const Duration(days: 7));
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Generate Shopping List'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create a shopping list based on your meal plan:'),
                SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'List Name',
                  ),
                ),
                SizedBox(height: 16),
                Text('Date Range:'),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              startDate = picked;
                              if (endDate.isBefore(startDate)) {
                                endDate = startDate.add(const Duration(days: 1));
                              }
                            });
                          }
                        },
                        child: Text(DateFormat('MMM d, y').format(startDate)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('to'),
                    ),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate,
                            firstDate: startDate,
                            lastDate: DateTime(2101),
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              endDate = picked;
                            });
                          }
                        },
                        child: Text(DateFormat('MMM d, y').format(endDate)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (nameController.text.trim().isNotEmpty) {
                    Navigator.pop(context);
                    
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                    
                    final generatedList = await ShoppingListService.generateFromMealPlan(
                      startDate, 
                      endDate, 
                      nameController.text.trim(),
                    );
                    
                    // Close loading dialog
                    Navigator.pop(context);
                    
                    if (generatedList != null) {
                      setState(() {
                        _shoppingLists.add(generatedList);
                      });
                      
                      _navigateToDetail(generatedList);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to generate shopping list')),
                      );
                    }
                  }
                },
                child: Text('Generate'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  void _showCreateListDialog() {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'List Name',
                hintText: 'e.g., Grocery List, Weekend Shopping',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                
                final newList = ShoppingList(name: name);
                await ShoppingListService.saveList(newList);
                
                setState(() {
                  _shoppingLists.add(newList);
                });
                
                _navigateToDetail(newList);
              }
            },
            child: Text('Create'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
  
  void _deleteList(ShoppingList list) async {
    final result = await ShoppingListService.deleteList(list.id);
    if (result) {
      setState(() {
        _shoppingLists.removeWhere((item) => item.id == list.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${list.name} deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await ShoppingListService.saveList(list);
              setState(() {
                _shoppingLists.add(list);
                _shoppingLists.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              });
            },
          ),
        ),
      );
    }
  }
  
  void _navigateToDetail(ShoppingList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShoppingListDetailPage(shoppingList: list),
      ),
    ).then((_) {
      // Refresh list when returning from detail page
      _loadShoppingLists();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: const NavigationPlannerAppBar(currentPage: 'shoppingList'),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(loc),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add_shopping_cart, color: Colors.green),
                  title: const Text('Create New List'),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateListDialog();
                  },
                ),
                // ListTile(
                //   leading: const Icon(Icons.restaurant_menu, color: Colors.blue),
                //   title: const Text('Generate From Meal Plan'),
                //   onTap: () {
                //     Navigator.pop(context);
                //     _showGenerateDialog();
                //   },
                // ),
              ],
            ),
          );
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 0),
    );
  }
  
  Widget _buildContent(AppLocalizations loc) {
    if (_shoppingLists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No shopping lists yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new list or generate one from your meal plan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showCreateListDialog,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Create List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                // OutlinedButton.icon(
                //   onPressed: _showGenerateDialog,
                //   icon: const Icon(Icons.restaurant_menu),
                //   label: const Text('From Meal Plan'),
                //   style: OutlinedButton.styleFrom(
                //     foregroundColor: Colors.blue,
                //     side: const BorderSide(color: Colors.blue),
                //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                //   ),
                // ),
              ],
            ),
          ],
        ),
      );
    }
    
    // Sort lists by creation date (newest first)
    _shoppingLists.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _shoppingLists.length,
      itemBuilder: (context, index) {
        final list = _shoppingLists[index];
        final formatter = DateFormat('MMM d, yyyy');
        final date = formatter.format(list.createdAt);
        
        // Get preview items (first 3)
        final previewItems = list.getPreviewItems();
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: list.isFromMealPlan ? Colors.blue.shade200 : Colors.green.shade200,
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () => _navigateToDetail(list),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icon to differentiate between custom and generated lists
                      Icon(
                        list.isFromMealPlan ? Icons.restaurant_menu : Icons.shopping_cart,
                        color: list.isFromMealPlan ? Colors.blue : Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      // List name and date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              list.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Progress indicator
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${list.checkedCount}/${list.items.length} items',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              value: list.completionPercentage,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                list.completionPercentage == 1.0 
                                    ? Colors.green 
                                    : list.isFromMealPlan ? Colors.blue : Colors.orange,
                              ),
                              strokeWidth: 5,
                            ),
                          ),
                        ],
                      ),
                      // Menu for options
                      PopupMenuButton(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteList(list);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (list.items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          // Preview of the first few items
                          for (var item in previewItems)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    item.checked ? Icons.check_box : Icons.check_box_outline_blank,
                                    color: item.checked ? Colors.green : Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${item.name} (${item.quantity} ${item.unit})',
                                      style: TextStyle(
                                        decoration: item.checked ? TextDecoration.lineThrough : null,
                                        color: item.checked ? Colors.grey : Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (list.items.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '+ ${list.items.length - 3} more items',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
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
}

