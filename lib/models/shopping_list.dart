import 'package:uuid/uuid.dart';

class ShoppingListItem {
  String id;
  String name;
  bool checked;
  String category;
  double quantity;
  String unit;

  ShoppingListItem({
    String? id,
    required this.name,
    this.checked = false,
    this.category = 'Other',
    this.quantity = 1,
    this.unit = 'pcs',
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'checked': checked,
      'category': category,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      id: json['id'],
      name: json['name'],
      checked: json['checked'] ?? false,
      category: json['category'] ?? 'Other',
      quantity: json['quantity'] ?? 1,
      unit: json['unit'] ?? 'pcs',
    );
  }
}

class ShoppingList {
  String id;
  String name;
  DateTime createdAt;
  List<ShoppingListItem> items;
  bool isFromMealPlan;

  ShoppingList({
    String? id,
    required this.name,
    DateTime? createdAt,
    List<ShoppingListItem>? items,
    this.isFromMealPlan = false,
  }) : 
      id = id ?? const Uuid().v4(),
      createdAt = createdAt ?? DateTime.now(),
      items = items ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'isFromMealPlan': isFromMealPlan,
    };
  }

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      items: (json['items'] as List)
          .map((item) => ShoppingListItem.fromJson(item))
          .toList(),
      isFromMealPlan: json['isFromMealPlan'] ?? false,
    );
  }

  // Helper method to get a preview of items (first 3)
  List<ShoppingListItem> getPreviewItems() {
    return items.take(3).toList();
  }
  
  // Get count of checked items
  int get checkedCount => items.where((item) => item.checked).length;
  
  // Get percentage of completion
  double get completionPercentage => items.isEmpty ? 0 : checkedCount / items.length;
}