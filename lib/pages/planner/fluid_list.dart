//// filepath: /c:/Users/footb/Documents/GitHub/vv2/FrontEnd/lib/pages/planner/planner/fluid_list.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:decideat/widgets/navigationPlannerAppBar.dart';
import 'package:decideat/widgets/bottomNavBar.dart';
import 'package:decideat/pages/planner.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/pages/planner/planner/add_fluid.dart';
import 'package:http/http.dart' as http;
import '../../api/api.dart';

class Fluid {
  final String id;
  final String fluidId;
  final String name;
  final int kcal;
  final int quantity; // in ml
  final double protein;
  final double carbs;
  final double fat;

  Fluid({
    required this.id,
    required this.fluidId,
    required this.name,
    required this.kcal,
    required this.quantity,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

class NutritionSummary {
  final int totalKcal;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final int totalVolume;

  NutritionSummary({
    required this.totalKcal,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalVolume,
  });

  factory NutritionSummary.fromFluids(List<Fluid> fluids) {
    int kcal = 0;
    double protein = 0.0;
    double carbs = 0.0;
    double fat = 0.0;
    int volume = 0;

    for (final fluid in fluids) {
      kcal += fluid.kcal;
      protein += fluid.protein;
      carbs += fluid.carbs;
      fat += fluid.fat;
      volume += fluid.quantity;
    }

    return NutritionSummary(
      totalKcal: kcal,
      totalProtein: protein,
      totalCarbs: carbs,
      totalFat: fat,
      totalVolume: volume,
    );
  }
}

class FluidList extends StatefulWidget {
  FluidList({Key? key}) : super(key: key);

  @override
  State<FluidList> createState() => _FluidListState();
}

class _FluidListState extends State<FluidList> {
  DateTime selectedDate = DateTime.now();
  bool _isLoading = true;
  List<Fluid> _fluids = [];
  double fluidIntakeInLiters = 0; // Added to track total fluid intake in liters
  double recommendedFluidIntake = 2.5; // Default recommended fluid intake in liters
  
  @override
  void initState() {
    super.initState();
    _fetchHealthData();
    _fetchFluids();
  }

  String formatQuantity(int quantity) {
    if (quantity > 1000) {
      double liters = quantity / 1000;
      return '${liters.toStringAsFixed(1)} L';
    }
    return '$quantity ml';
  }

  // Helper method to format nutrition values
  String formatNutrition(dynamic value) {
    if (value is int) {
      return value.toString();
    }
    // Format to max 2 decimal places and remove trailing zeros
    return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0*$'), '');
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickDate() async {
    final currentLocale = Localizations.localeOf(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: currentLocale, // Pass the current locale here
    );
    if (picked != null && !_isSameDay(picked, selectedDate)) {
      setState(() {
        selectedDate = picked;
      });
      _fetchFluids();
    }
  }

  void _changeDate(int days) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: days));
    });
    _fetchFluids();
  }

  Future<void> _fetchFluids() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await RefreshTokenIfExpired();
      final accessToken = await storage.read(key: 'accessToken');
      
      // Format date as YYYY-MM-DD for API
      final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
      
      final url = Uri.parse('$apiUrl/user/planner/meals');
      print('Fetching fluids for date: $formattedDate');
      
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'date': formattedDate,
        }),
      );
      
      print('Fluid list response status: ${response.statusCode}');
      print('Fluid list response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> fluidDetails = [];
        // Parse response as a Map instead of a List
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Get fluidIntakeAmount if available in the planner data
        if (data.containsKey('planner') && data['planner'] != null) {
          // Convert ml to liters
          final fluidIntakeAmount = data['planner']['fluidIntakeAmount'] ?? 0;
          fluidIntakeInLiters = fluidIntakeAmount / 1000.0;
        }
        
        // Check if we have data for the day with the corrected structure
        if (data.containsKey('planner') && data['planner'] != null && 
            data['planner']['fluids'] != null) {
          final fluids = data['planner']['fluids'] as List<dynamic>;
          
          print('Found ${fluids.length} fluids in the response');
          
          // For each fluid, fetch details
          for (var fluid in fluids) {
            try {
              final fluidId = fluid['fluidId'];
              final amount = fluid['amount'];
              final fluidDetailUrl = Uri.parse('$apiUrl/product/$fluidId');
              
              print('Fetching details for fluid ID: $fluidId');
              
              final detailsResponse = await http.get(
                fluidDetailUrl,
                headers: <String, String>{
                  'Content-Type': 'application/json; charset=UTF-8',
                  'Authorization': 'Bearer $accessToken',
                },
              );
              
              if (detailsResponse.statusCode == 200) {
                final fluidDetail = json.decode(detailsResponse.body);
                print('Got details for fluid: ${fluidDetail['name']}');
                
                // Safely parse nutrition values
                double parseNutritionValue(dynamic value) {
                  if (value == null) return 0.0;
                  if (value is num) return value.toDouble();
                  
                  try {
                    return double.parse(value.toString());
                  } catch (e) {
                    print('Warning: Could not parse nutrition value: $value');
                    return 0.0;
                  }
                }
                
                try {
                  // Safe parsing with fallbacks
                  final kcalValue = parseNutritionValue(fluidDetail['kcalPortion']);
                  final proteinValue = parseNutritionValue(fluidDetail['proteinPortion']);
                  final carbsValue = parseNutritionValue(fluidDetail['carbohydratesPortion']);
                  final fatValue = parseNutritionValue(fluidDetail['fatPortion']);
                  
                  // Calculate with amount
                  final kcal = (kcalValue * amount / 100).round();
                  final protein = proteinValue * amount / 100;
                  final carbs = carbsValue * amount / 100;
                  final fat = fatValue * amount / 100;
                  
                  // Print debug info for nutritional values
                  print('Parsed nutrition - kcal: $kcalValue, protein: $proteinValue, carbs: $carbsValue, fat: $fatValue');
                  print('Calculated for amount ($amount ml) - kcal: $kcal, protein: $protein, carbs: $carbs, fat: $fat');
                  
                  fluidDetails.add({
                    'id': fluid['_id'],
                    'fluidId': fluidId,
                    'name': fluidDetail['name'] ?? 'Unknown Fluid',
                    'kcal': kcal,
                    'quantity': amount,
                    'protein': protein,
                    'carbs': carbs,
                    'fat': fat,
                  });
                } catch (e) {
                  print('Error processing fluid nutritional data: $e');
                  // Add basic info even if nutritional calculations fail
                  fluidDetails.add({
                    'id': fluid['_id'],
                    'fluidId': fluidId,
                    'name': fluidDetail['name'] ?? 'Unknown Fluid',
                    'kcal': 0,
                    'quantity': amount,
                    'protein': 0.0,
                    'carbs': 0.0,
                    'fat': 0.0,
                  });
                }
              } else {
                print('Failed to get fluid details: ${detailsResponse.statusCode}');
                print('Response: ${detailsResponse.body}');
              }
            } catch (e) {
              print('Error fetching fluid details: $e');
            }
          }
        } else {
          print('No fluids found in response or empty response');
        }
        
        // Convert to Fluid objects
        final fluidsList = fluidDetails.map((item) => Fluid(
          id: item['id'],
          fluidId: item['fluidId'],
          name: item['name'],
          kcal: item['kcal'],
          quantity: item['quantity'],
          protein: item['protein'],
          carbs: item['carbs'],
          fat: item['fat'],
        )).toList();
        
        setState(() {
          _fluids = fluidsList;
          _isLoading = false;
        });
      } else {
        print('Failed to load fluids list: ${response.statusCode}');
        print('Response: ${response.body}');
        setState(() {
          _fluids = [];
          _isLoading = false;
        });
        
        // Don't show error snackbar for 404 or "planner doesn't exist" responses
        // These are expected states, not actual errors from the user's perspective
        if (response.statusCode != 404 && 
            !(response.body.contains("Planner doesn't exist") || 
              response.body.toLowerCase().contains("planner not found"))) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load fluids: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('Error in _fetchFluids: $e');
      setState(() {
        _fluids = [];
        _isLoading = false;
      });
      
      // Only show error snackbar for unexpected errors
      // Don't display errors for normal states like "planner not found"
      String errorMessage = e.toString().toLowerCase();
      if (!errorMessage.contains("planner not found") && 
          !errorMessage.contains("planner doesn't exist") &&
          !errorMessage.contains("404")) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Fetch user's health data including recommended fluid intake
  Future<void> _fetchHealthData() async {
    try {
      await RefreshTokenIfExpired();
      final accessToken = await storage.read(key: 'accessToken');
      
      final url = Uri.parse('$apiUrl/user/health-data');
      
      final response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
        },
      );
      
      print('Health data response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Health data: $data');
        
        setState(() {
          // Convert from ml to liters and store the user's recommended fluid intake
          if (data.containsKey('fluidIntakeAmount')) {
            recommendedFluidIntake = data['fluidIntakeAmount'] / 1000.0;
          }
        });
      } else {
        print('Failed to load health data: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error fetching health data: $e');
    }
  }

  Widget buildDateHeader() {
    final currentLocale = Localizations.localeOf(context);
    final formattedDate =
        DateFormat.yMMMMd(currentLocale.toString()).format(selectedDate);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_left),
          onPressed: () => _changeDate(-1),
        ),
        GestureDetector(
          onTap: _pickDate,
          child: Text(
            formattedDate,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_right),
          onPressed: () => _changeDate(1),
        ),
      ],
    );
  }

  // Helper widget to build nutrient columns.
  Widget _buildNutrientColumn(
      String label, IconData icon, String unit, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text('$value $unit', style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ],
    );
  }
  
  // Build the nutritional summary card
  Widget _buildNutritionSummaryCard(NutritionSummary summary, AppLocalizations loc) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Fluid Intake Summary",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    formatQuantity(summary.totalVolume),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientColumn(
                  loc.caloriesLabel,
                  Icons.local_fire_department,
                  "kcal",
                  formatNutrition(summary.totalKcal),
                  Colors.redAccent,
                ),
                _buildNutrientColumn(
                  loc.proteinLabel,
                  Icons.scale,
                  "g",
                  formatNutrition(summary.totalProtein),
                  Colors.blue,
                ),
                _buildNutrientColumn(
                  loc.carbsLabel,
                  Icons.grain,
                  "g",
                  formatNutrition(summary.totalCarbs),
                  Colors.orange,
                ),
                _buildNutrientColumn(
                  loc.fatLabel,
                  Icons.opacity,
                  "g",
                  formatNutrition(summary.totalFat),
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build the fluid intake card
  Widget _buildFluidIntakeCard(AppLocalizations loc, NutritionSummary summary) {
    // Convert the total volume from ml to liters for display
    final totalVolumeInLiters = summary.totalVolume / 1000.0;
    
    // Update fluid intake in liters based on the summary
    fluidIntakeInLiters = totalVolumeInLiters;
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.water_drop, size: 24, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      loc.fluidIntake,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${formatNutrition(fluidIntakeInLiters)} L / ${formatNutrition(recommendedFluidIntake)} L',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: fluidIntakeInLiters >= recommendedFluidIntake 
                        ? Colors.green 
                        : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: recommendedFluidIntake > 0 
                    ? fluidIntakeInLiters / recommendedFluidIntake 
                    : 0, // Using personalized target
                minHeight: 12,
                backgroundColor: Colors.blue.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(
                  fluidIntakeInLiters >= recommendedFluidIntake ? Colors.green : Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatNutrition(fluidIntakeInLiters / recommendedFluidIntake * 100)}% of daily recommended intake',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    // Calculate nutritional summary
    final summary = NutritionSummary.fromFluids(_fluids);
    
    return Scaffold(
      appBar: NavigationPlannerAppBar(currentPage: 'fluidList'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade50,
              const Color.fromARGB(0, 255, 255, 255),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            buildDateHeader(), 
            const SizedBox(height: 8),
            _isLoading 
              ? Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Loading fluid data...",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _fluids.isEmpty
                ? Expanded(
                    child: Column(
                      children: [
                        // Add fluid intake card even when no fluids are logged
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _buildFluidIntakeCard(loc, summary),
                        ),
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.water_drop_outlined,
                                  size: 48,
                                  color: Colors.blue.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No fluids recorded for this date',
                                  style: TextStyle(
                                    fontSize: 16, 
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the + button to add a fluid',
                                  style: TextStyle(
                                    fontSize: 14, 
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Expanded(
                  child: Column(
                    children: [
                      // Add the fluid intake card above nutritional summary card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildFluidIntakeCard(loc, summary),
                      ),
                      // Add the nutritional summary card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildNutritionSummaryCard(summary, loc),
                      ),
                      Expanded(
                        child: LayoutBuilder(builder: (context, constraints) {
                          // Build grid layout for larger screens.
                          if (constraints.maxWidth > 600) {
                            return GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: constraints.maxWidth > 900 ? 3 : 2,
                                childAspectRatio: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _fluids.length,
                              itemBuilder: (context, index) {
                                final fluid = _fluids[index];
                                return Card(
                                  elevation: 3,
                                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Left side: Photo & Fluid details.
                                        Expanded(
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: Colors.blue[100],
                                                radius: 25,
                                                child: Icon(Icons.water_drop, color: Colors.blue),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      fluid.name,
                                                      style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.w600),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        _buildNutrientColumn(loc.proteinLabel, Icons.scale,
                                                            "g", formatNutrition(fluid.protein), Colors.blue),
                                                        const SizedBox(width: 8),
                                                        _buildNutrientColumn(loc.carbsLabel, Icons.grain,
                                                            "g", formatNutrition(fluid.carbs), Colors.orange),
                                                        const SizedBox(width: 8),
                                                        _buildNutrientColumn(loc.fatLabel, Icons.opacity,
                                                            "g", formatNutrition(fluid.fat), Colors.purple),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Right side: Calories with icon and Quantity.
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            _buildNutrientColumn(loc.caloriesLabel,
                                                Icons.local_fire_department, "kcal", formatNutrition(fluid.kcal), Colors.redAccent),
                                            const SizedBox(height: 4),
                                            Text(
                                              formatQuantity(fluid.quantity),
                                              style: const TextStyle(
                                                  fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          } else {
                            // Build list layout for smaller screens.
                            return ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _fluids.length,
                              itemBuilder: (context, index) {
                                final fluid = _fluids[index];
                                return Card(
                                  elevation: 3,
                                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.blue[100],
                                          radius: 25,
                                          child: Icon(Icons.water_drop, color: Colors.blue),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                fluid.name,
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  _buildNutrientColumn(loc.proteinLabel, Icons.scale,
                                                      "g", formatNutrition(fluid.protein), Colors.blue),
                                                  const SizedBox(width: 8),
                                                  _buildNutrientColumn(loc.carbsLabel, Icons.grain,
                                                      "g", formatNutrition(fluid.carbs), Colors.orange),
                                                  const SizedBox(width: 8),
                                                  _buildNutrientColumn(loc.fatLabel, Icons.opacity,
                                                      "g", formatNutrition(fluid.fat), Colors.purple),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            _buildNutrientColumn(loc.caloriesLabel,
                                                Icons.local_fire_department, "kcal", formatNutrition(fluid.kcal), Colors.redAccent),
                                            const SizedBox(height: 4),
                                            Text(
                                              formatQuantity(fluid.quantity),
                                              style: const TextStyle(
                                                  fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        }),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddFluidPage(selectedDate: selectedDate),
            ),
          );
          if (result == true) {
            _fetchFluids(); // Refresh the list after returning from AddFluidPage
          }
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 0),
    );
  }
}
