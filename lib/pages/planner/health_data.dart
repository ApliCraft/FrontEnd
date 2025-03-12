import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../api/api.dart';
import 'package:decideat/widgets/navigationPlannerAppBar.dart';
import 'package:decideat/widgets/bottomNavBar.dart';

class HealthData extends StatefulWidget {
  const HealthData({Key? key}) : super(key: key);

  @override
  State<HealthData> createState() => _HealthDataState();
}

class _HealthDataState extends State<HealthData> {
  bool _isLoading = true;
  bool _needsDataInput = false;
  Map<String, dynamic> _healthData = {};
  String? _token;
  final _storage = const FlutterSecureStorage();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String _selectedGender = 'male';
  int _activityLevel = 2;

  bool _isLoadingUserInfo = false;
  int _userAge = 0;
  double _ppm = 0; // Basal Metabolic Rate
  double _cpm = 0; // Total Metabolic Rate

  final List<Map<String, dynamic>> _activityLevels = [
    {'level': 0, 'description': 'None (sick person, lying in bed)'},
    {'level': 1, 'description': 'Small (person doing sedentary work)'},
    {'level': 2, 'description': 'Moderate (person doing standing work)'},
    {
      'level': 3,
      'description':
          'Large (person leading an active lifestyle, exercising regularly)'
    },
    {
      'level': 4,
      'description':
          'Very large (person leading a very active lifestyle, exercising daily)'
    },
    {
      'level': 5,
      'description': 'Professional (person doing sports professionally)'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadToken().then((_) {
      _fetchHealthData();
      _fetchUserInfo();
    });
  }

  Future<void> _loadToken() async {
    try {
      // Refresh token if expired
      await RefreshTokenIfExpired();

      final accessToken = await _storage.read(key: 'accessToken');
      setState(() {
        _token = accessToken;
      });
    } catch (e) {
      // Handle token retrieval error
    }
  }

  Future<void> _fetchHealthData() async {
    try {
      // Refresh token if expired
      await RefreshTokenIfExpired();
      final accessToken = await _storage.read(key: 'accessToken');

      if (accessToken == null) {
        setState(() {
          _isLoading = false;
          _needsDataInput = true; // Show form when not authenticated
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$apiUrl/user/health-data'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _healthData = data;
          _needsDataInput = data.containsKey('fluidIntakeAmount') &&
              !(data.containsKey('height') &&
                  data.containsKey('weight') &&
                  data.containsKey('gender') &&
                  data.containsKey('activityLevel'));
          _isLoading = false;
        });

        // Pre-fill form if data exists
        if (data.containsKey('height')) {
          _heightController.text = data['height'].toString();
        }
        if (data.containsKey('weight')) {
          _weightController.text = data['weight'].toString();
        }
        if (data.containsKey('gender')) {
          _selectedGender = data['gender'];
        }
        if (data.containsKey('activityLevel')) {
          _activityLevel = data['activityLevel'];
        }

        // If user age is loaded and health data is complete, calculate calorie requirements
        if (_userAge > 0 && !_needsDataInput && data.containsKey('height')) {
          _calculateCalorieRequirements();
        }
      } else {
        setState(() {
          _needsDataInput = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  Future<void> _fetchUserInfo() async {
    setState(() {
      _isLoadingUserInfo = true;
    });

    try {
      // Refresh token if expired
      await RefreshTokenIfExpired();
      final accessToken = await _storage.read(key: 'accessToken');

      if (accessToken == null) {
        setState(() {
          _isLoadingUserInfo = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$apiUrl/user/user-info'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data.containsKey('dateOfBirth') && data['dateOfBirth'] != null) {
          final dateOfBirth = DateTime.parse(data['dateOfBirth']);
          final now = DateTime.now();
          
          // Calculate age in years
          int age = now.year - dateOfBirth.year;
          // Adjust age if birthday hasn't occurred this year yet
          if (now.month < dateOfBirth.month || 
              (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
            age--;
          }
          
          setState(() {
            _userAge = age;
            _isLoadingUserInfo = false;
          });
          
          // If health data is already loaded, calculate calorie requirements
          if (!_isLoading && !_needsDataInput && _healthData.containsKey('height')) {
            _calculateCalorieRequirements();
          }
        } else {
          setState(() {
            _isLoadingUserInfo = false;
          });
        }
      } else {
        setState(() {
          _isLoadingUserInfo = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingUserInfo = false;
      });
    }
  }

  void _calculateCalorieRequirements() {
    if (_userAge <= 0 || !_healthData.containsKey('height') || 
        !_healthData.containsKey('weight') || !_healthData.containsKey('gender') || 
        !_healthData.containsKey('activityLevel')) {
      return;
    }

    final height = _healthData['height'].toDouble();
    final weight = _healthData['weight'].toDouble();
    final gender = _healthData['gender'].toString();
    final activityLevel = _healthData['activityLevel'] as int;

    // Calculate Basal Metabolic Rate (PPM)
    double ppm = 0;
    if (gender == 'female') {
      ppm = 655.1 + (9.563 * weight) + (1.85 * height) - (4.676 * _userAge);
    } else { // male
      ppm = 66.473 + (13.752 * weight) + (5.003 * height) - (6.775 * _userAge);
    }

    // Get physical activity coefficient based on activity level
    double activityCoefficient = _getActivityCoefficient(activityLevel);

    // Calculate Total Metabolic Rate (CPM)
    double cpm = ppm * activityCoefficient;

    setState(() {
      _ppm = ppm;
      _cpm = cpm;
    });
  }

  double _getActivityCoefficient(int activityLevel) {
    switch (activityLevel) {
      case 0:
        return 1.2; // none (sick person, lying in bed)
      case 1:
        return 1.4; // low (person performing sedentary work)
      case 2:
        return 1.6; // moderate (person performing standing work)
      case 3:
        return 1.75; // high (person leading an active lifestyle, exercising regularly)
      case 4:
        return 2.0; // very high (person leading a very active lifestyle, exercising daily)
      case 5:
        return 2.4; // person practicing sports professionally
      default:
        return 1.6; // default to moderate
    }
  }

  Future<void> _submitHealthData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Refresh token if expired
      await RefreshTokenIfExpired();
      final accessToken = await _storage.read(key: 'accessToken');

      if (accessToken == null) {
        throw Exception('Authentication required');
      }

      final response = await http.put(
        Uri.parse('$apiUrl/user/update-user-health-data'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'height': double.parse(_heightController.text),
          'weight': double.parse(_weightController.text),
          'gender': _selectedGender,
          'activityLevel': _activityLevel,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health data updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchHealthData(); // Refresh data
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to update health data: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 16) {
      return 'Severe Thinness';
    } else if (bmi < 17) {
      return 'Moderate Thinness';
    } else if (bmi < 18.5) {
      return 'Mild Thinness';
    } else if (bmi < 25) {
      return 'Normal';
    } else if (bmi < 30) {
      return 'Overweight';
    } else if (bmi < 35) {
      return 'Obese Class I';
    } else if (bmi < 40) {
      return 'Obese Class II';
    } else {
      return 'Obese Class III';
    }
  }

  Color _getBmiCategoryColor(String category) {
    switch (category) {
      case 'Severe Thinness':
      case 'Moderate Thinness':
      case 'Mild Thinness':
        return Colors.blue;
      case 'Normal':
        return Colors.green;
      case 'Overweight':
        return Colors.orange;
      case 'Obese Class I':
      case 'Obese Class II':
      case 'Obese Class III':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDataInputForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Health Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _heightController,
            decoration: const InputDecoration(
              labelText: 'Height (cm)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.height),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your height';
              }
              final height = double.tryParse(value);
              if (height == null || height <= 0 || height > 300) {
                return 'Please enter a valid height';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.line_weight),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your weight';
              }
              final weight = double.tryParse(value);
              if (weight == null || weight <= 0 || weight > 500) {
                return 'Please enter a valid weight';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Gender',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'male',
                label: Text('Male'),
                icon: Icon(Icons.male),
              ),
              ButtonSegment<String>(
                value: 'female',
                label: Text('Female'),
                icon: Icon(Icons.female),
              ),
            ],
            selected: {_selectedGender},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _selectedGender = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Activity Level',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            _activityLevels.length,
            (index) => RadioListTile<int>(
              title: Text(_activityLevels[index]['description']),
              value: _activityLevels[index]['level'],
              groupValue: _activityLevel,
              onChanged: (int? value) {
                setState(() {
                  _activityLevel = value!;
                });
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitHealthData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Health Data'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthDataDisplay() {
    final height = _healthData['height'].toDouble();
    final weight = _healthData['weight'].toDouble();
    final gender = _healthData['gender'].toString();
    final activityLevel = _healthData['activityLevel'] as int;
    final activityDescription = _activityLevels.firstWhere((element) => element['level'] == activityLevel)['description'];

    // Calculate BMI
    final heightInMeters = height / 100;
    final bmi = weight / (heightInMeters * heightInMeters);
    final bmiCategory = _getBmiCategory(bmi);
    final categoryColor = _getBmiCategoryColor(bmiCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title (without update button)
        const Text(
          'Your Health Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),

        // Health metrics cards - Row 1
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Height',
                '$height cm',
                Icons.height,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Weight',
                '$weight kg',
                Icons.line_weight,
                Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Health metrics cards - Row 2
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Gender',
                gender.capitalize(),
                gender == 'male' ? Icons.male : Icons.female,
                gender == 'male' ? Colors.blue.shade700 : Colors.pink.shade300,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActivityLevelCard(activityLevel, activityDescription),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // BMI Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.health_and_safety, color: categoryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Body Mass Index (BMI)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bmi.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bmiCategory,
                          style: TextStyle(
                            fontSize: 16,
                            color: categoryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        children: [
                          Center(
                            child: SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                value: bmi / 50, // 50 is max BMI for gauge
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    categoryColor),
                                strokeWidth: 10,
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              bmi.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Calorie Card (only show if age has been loaded)
        if (_userAge > 0) ...[
          const SizedBox(height: 16),
          _buildCalorieCard(_ppm, _cpm),
        ] else if (_isLoadingUserInfo) ...[
          const SizedBox(height: 16),
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Calculating calorie requirements...'),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
        
        // Update button - now at the bottom and centered
        Center(
          child: ElevatedButton.icon(
            onPressed: () {
              // Pre-fill form with existing data
              _heightController.text = height.toString();
              _weightController.text = weight.toString();
              _selectedGender = _healthData['gender'];
              _activityLevel = _healthData['activityLevel'];
              
              setState(() {
                _needsDataInput = true;
              });
            },
            icon: const Icon(Icons.edit, size: 18, color: Colors.white),
            label: const Text('Update'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActivityLevelCard(int level, String description) {
    // Get color based on activity level
    final Color activityColor = _getActivityLevelColor(level);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fitness_center, color: activityColor),
                const SizedBox(width: 8),
                const Text(
                  'Activity Level',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  level.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: activityColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: level / 5, // 5 is max activity level
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(activityColor),
                      minHeight: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _getActivityShortDescription(level),
              style: TextStyle(
                fontSize: 14,
                color: activityColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getActivityShortDescription(int level) {
    switch (level) {
      case 0:
        return 'None';
      case 1:
        return 'Small';
      case 2:
        return 'Moderate';
      case 3:
        return 'Large';
      case 4:
        return 'Very Large';
      case 5:
        return 'Professional';
      default:
        return 'Unknown';
    }
  }

  Color _getActivityLevelColor(int level) {
    switch (level) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.blue.shade300;
      case 2:
        return Colors.green.shade400;
      case 3:
        return Colors.orange.shade400;
      case 4:
        return Colors.deepOrange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieCard(double ppm, double cpm) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.deepOrange),
                const SizedBox(width: 8),
                const Text(
                  'Daily Calorie Requirements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BMR (Basic): ${ppm.round()} kcal',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${cpm.round()} kcal',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'daily',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: Colors.deepOrange,
                          size: 40,
                        ),
                        Text(
                          'TDEE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Based on age: $_userAge years',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavigationPlannerAppBar(currentPage: 'healthData'),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your health data...'),
                ],
              ),
            )
          : Container(
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
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: _needsDataInput
                      ? _buildDataInputForm()
                      : _buildHealthDataDisplay(),
                ),
              ),
            ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 0),
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}

// Extension for capitalizing strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
