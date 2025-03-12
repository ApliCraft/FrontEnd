import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/planner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AddMealPage extends StatefulWidget {
  final DateTime selectedDate;
  
  const AddMealPage({
    Key? key, 
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<AddMealPage> createState() => _AddMealPageState();
}

class _AddMealPageState extends State<AddMealPage> {
  String _selectedType = 'product';
  String _selectedCategory = 'breakfast';
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _portionController = TextEditingController();
  bool _isLoading = false;
  
  final List<String> _mealTypes = ['product', 'recipe'];
  final List<String> _mealCategories = ['breakfast', 'lunch', 'dinner', 'snack'];
  
  @override
  void dispose() {
    _idController.dispose();
    _portionController.dispose();
    super.dispose();
  }
  
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
  
  String _getFormattedTime() {
    final hour = _selectedTime.hour.toString().padLeft(2, '0');
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  Future<void> _addMeal() async {
    if (_idController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid ID')),
      );
      return;
    }
    
    if (_portionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid portion')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Format the date and time
      final formattedDate = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ).toIso8601String();
      
      // Call the API to add the meal
      await ApiServicePlanner.addMeal(
        date: formattedDate,
        type: _selectedType,
        id: _idController.text,
        category: _selectedCategory,
        portion: double.parse(_portionController.text),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal added successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding meal: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, d MMMM');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Meal'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selected date display
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Date: ${dateFormat.format(widget.selectedDate)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Meal type selection
                  const Text(
                    'Type:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedType = newValue;
                        });
                      }
                    },
                    items: _mealTypes.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value.capitalize()),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ID input
                  const Text(
                    'ID:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter product or recipe ID',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Meal category selection
                  const Text(
                    'Category:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      }
                    },
                    items: _mealCategories.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value.capitalize()),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Time selection
                  const Text(
                    'Time:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: () => _selectTime(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_getFormattedTime()),
                          const Icon(Icons.access_time),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Portion input
                  const Text(
                    'Portion:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextField(
                    controller: _portionController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Enter portion amount',
                      suffixText: _selectedType == 'product' ? 'g' : 'servings',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Add button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addMeal,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Add Meal',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
} 