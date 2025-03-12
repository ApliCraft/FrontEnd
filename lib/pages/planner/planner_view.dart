import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/widgets/navigationPlannerAppBar.dart';
import 'package:decideat/widgets/bottomNavBar.dart';
import 'package:decideat/pages/planner/fluid_list.dart';
import 'package:decideat/pages/planner/planner/edit_planner.dart';

class PlannerViewPage extends StatefulWidget {
  const PlannerViewPage({Key? key}) : super(key: key);

  @override
  _PlannerViewPageState createState() => _PlannerViewPageState();
}

class _PlannerViewPageState extends State<PlannerViewPage> {
  DateTime _selectedDate = DateTime.now();
  bool _showCalendar = false;
  double _fluidIntake = 1.0; // in liters
  bool _isLoading = false;
  
  final Map<DateTime, List<Map<String, dynamic>>> _mealEvents = {};

  @override
  void initState() {
    super.initState();
    _loadMealEvents();
  }

  Future<void> _loadMealEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement API call to load meal events
      // Example API structure:
      // final response = await http.get('$apiUrl/planner/meals?date=${_selectedDate.toIso8601String()}');
      // final data = json.decode(response.body);
      // _mealEvents[_selectedDate] = List<Map<String, dynamic>>.from(data);
      
      setState(() {
        _mealEvents.clear();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading meal events: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading meals: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    // Normalize the date to avoid time comparison issues
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _mealEvents[normalizedDay] ?? [];
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (picked != null && !_isSameDay(picked, _selectedDate)) {
      setState(() {
        _selectedDate = picked;
        _showCalendar = false; // Hide calendar after selection
      });
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  void _toggleCalendarVisibility() {
    setState(() {
      _showCalendar = !_showCalendar;
    });
  }

  Future<void> _navigateToEditPlanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPlannerPage(
          selectedDate: _selectedDate,
        ),
      ),
    );
    
    // Handle result if needed, for example, refresh the data
    if (result != null) {
      // TODO: Refresh meal plan data
    }
  }

  void _editMealItem(Map<String, dynamic> meal) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Change Time'),
              onTap: () async {
                Navigator.pop(context);
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  // TODO: Implement API call to update meal time
                  _loadMealEvents(); // Refresh the list
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.rice_bowl),
              title: const Text('Change Portion'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement portion adjustment dialog
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete Meal'),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () async {
                Navigator.pop(context);
                // TODO: Implement API call to delete meal
                _loadMealEvents(); // Refresh the list
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final eventsForSelectedDay = _getEventsForDay(_selectedDate);
    
    return Scaffold(
      appBar: NavigationPlannerAppBar(currentPage: 'planner'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade50,
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Date selector with expandable calendar
            _buildDateHeader(),
            
            // Expandable calendar (simplified version)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showCalendar ? 170 : 0,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: _buildSimpleCalendar(),
              ),
            ),
            
            // Daily summary cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: _buildNutritionSummaryCard(eventsForSelectedDay)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildFluidSummaryCard()),
                ],
              ),
            ),
            
            // Meal list
            Expanded(
              child: eventsForSelectedDay.isEmpty
                  ? _buildEmptyState()
                  : _buildMealList(eventsForSelectedDay),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToEditPlanner,
        backgroundColor: Theme.of(context).primaryColor,
        label: const Text('Edit Plan'),
        icon: const Icon(Icons.edit_calendar),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: const BottomNavBar(initialIndex: 0),
    );
  }

  Widget _buildDateHeader() {
    final dateFormatter = DateFormat('EEEE, MMMM d');
    final formattedDate = dateFormatter.format(_selectedDate);
    
    return GestureDetector(
      onTap: _toggleCalendarVisibility,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _showCalendar ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCalendar() {
    final now = DateTime.now();
    final currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Month selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month - 1,
                      _selectedDate.day > 28 ? 28 : _selectedDate.day,
                    );
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(currentMonth),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month + 1,
                      _selectedDate.day > 28 ? 28 : _selectedDate.day,
                    );
                  });
                },
              ),
            ],
          ),
          
          // Quick date selector
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickDateButton(now.subtract(const Duration(days: 2)), "2 days ago"),
              _buildQuickDateButton(now.subtract(const Duration(days: 1)), "Yesterday"),
              _buildQuickDateButton(now, "Today"),
              _buildQuickDateButton(now.add(const Duration(days: 1)), "Tomorrow"),
              _buildQuickDateButton(now.add(const Duration(days: 2)), "In 2 days"),
            ],
          ),
          
          // "Select custom date" button
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: const Text("Select custom date"),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDateButton(DateTime date, String label) {
    final isSelected = _isSameDay(date, _selectedDate);
    final hasEvents = _getEventsForDay(date).isNotEmpty;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
          _showCalendar = false;
        });
      },
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : hasEvents
                      ? Theme.of(context).primaryColor.withOpacity(0.2)
                      : Colors.grey.shade200,
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No meals planned for this day',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToEditPlanner,
            icon: const Icon(Icons.add),
            label: const Text('Add Meals'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealList(List<Map<String, dynamic>> meals) {
    // Sort meals by time
    meals.sort((a, b) => a['time'].compareTo(b['time']));
    
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90), // Bottom padding for FAB
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final meal = meals[index];
        return _buildMealCard(meal);
      },
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    final mealTypeColors = {
      'Breakfast': Colors.amber.shade700,
      'Lunch': Colors.green.shade700,
      'Dinner': Colors.blue.shade700,
      'Snack': Colors.purple.shade700,
    };
    
    final mealTypeIcons = {
      'Breakfast': Icons.free_breakfast,
      'Lunch': Icons.lunch_dining,
      'Dinner': Icons.dinner_dining,
      'Snack': Icons.cookie,
    };
    
    final color = mealTypeColors[meal['category']] ?? Colors.grey;
    final icon = mealTypeIcons[meal['category']] ?? Icons.restaurant;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time and meal type
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(icon, color: color, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        meal['time'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Meal details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${meal['category']} · ${meal['type'] == 'recipe' ? 'Recipe' : 'Product'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Menu button
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _editMealItem(meal),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            // Nutrition info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientInfo(
                  Icons.local_fire_department,
                  '${meal['calories']}',
                  'kcal',
                  Colors.deepOrange,
                ),
                _buildNutrientInfo(
                  Icons.fitness_center,
                  '${meal['protein']}',
                  'g protein',
                  Colors.purple,
                ),
                _buildNutrientInfo(
                  Icons.grain,
                  '${meal['carbs']}',
                  'g carbs',
                  Colors.amber.shade700,
                ),
                _buildNutrientInfo(
                  Icons.opacity,
                  '${meal['fat']}',
                  'g fat',
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientInfo(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionSummaryCard(List<Map<String, dynamic>> meals) {
    // Calculate totals
    int totalCalories = 0;
    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFat = 0;
    
    for (final meal in meals) {
      totalCalories += meal['calories'] as int;
      totalProtein += meal['protein'] as int;
      totalCarbs += meal['carbs'] as int;
      totalFat += meal['fat'] as int;
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nutrition',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${meals.length} meals',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientSummary(
                  Icons.local_fire_department,
                  totalCalories.toString(),
                  'kcal',
                  Colors.deepOrange,
                ),
                _buildNutrientSummary(
                  Icons.fitness_center,
                  totalProtein.toString(),
                  'g',
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientSummary(
                  Icons.grain,
                  totalCarbs.toString(),
                  'g carbs',
                  Colors.amber.shade700,
                ),
                _buildNutrientSummary(
                  Icons.opacity,
                  totalFat.toString(),
                  'g fat',
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFluidSummaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FluidList()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Water',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.water_drop,
                    color: Colors.blue.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 50,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade200,
                ),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: _fluidIntake / 2.5, // Target is 2.5L
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.blue.shade400,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${_fluidIntake.toStringAsFixed(1)}L / 2.5L',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _fluidIntake = _fluidIntake + 0.25 > 2.5 ? 2.5 : _fluidIntake + 0.25;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add 250ml'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientSummary(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
              TextSpan(
                text: ' $label',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}