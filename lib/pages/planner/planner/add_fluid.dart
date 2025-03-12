import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../api/api.dart';

class AddFluidPage extends StatefulWidget {
  final DateTime selectedDate;
  const AddFluidPage({Key? key, required this.selectedDate}) : super(key: key);

  @override
  _AddFluidPageState createState() => _AddFluidPageState();
}

class _AddFluidPageState extends State<AddFluidPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedFluidId;
  int _quantity = 250;
  bool _isLoading = true;
  List<dynamic> _fluids = [];
  final TextEditingController _customQuantityController = TextEditingController();

  // Helper method to safely build nutrition text
  Widget _buildNutrientText(Map<dynamic, dynamic> fluid) {
    try {
      // Handle nulls and format values properly
      final protein = fluid['proteinPortion'];
      final carbs = fluid['carbohydratesPortion'];
      final fat = fluid['fatPortion'];
      
      if (protein != null && carbs != null && fat != null) {
        return Text(
          'P: ${protein}g | C: ${carbs}g | F: ${fat}g',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        );
      } else {
        // Show partial data if available
        final parts = <String>[];
        if (protein != null) parts.add('P: ${protein}g');
        if (carbs != null) parts.add('C: ${carbs}g');
        if (fat != null) parts.add('F: ${fat}g');
        
        return Text(
          parts.isEmpty ? 'Nutritional info not available' : parts.join(' | '),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        );
      }
    } catch (e) {
      print('Error formatting nutritional info: $e');
      return Text(
        'Nutritional info not available',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchFluids();
  }

  Future<void> _fetchFluids() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await RefreshTokenIfExpired();
      final accessToken = await storage.read(key: 'accessToken');
      
      final url = Uri.parse('$apiUrl/product/filter');
      print('Fetching available fluid types');
      
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          "class": "Fluids"
        }),
      );
      
      print('Fluid types response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Found ${data.length} fluid types');
        
        if (data.isEmpty) {
          print('Warning: No fluid types returned from API');
        } else {
          for (var fluid in data) {
            print('Fluid type: ${fluid['name']} - ID: ${fluid['_id']}');
          }
        }
        
        setState(() {
          _fluids = data;
          _isLoading = false;
          if (_fluids.isNotEmpty) {
            _selectedFluidId = _fluids[0]['_id'];
          }
        });
      } else {
        print('Failed to load fluid types: ${response.statusCode}');
        print('Response: ${response.body}');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load fluids: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error in _fetchFluids: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _addFluid() async {
    if (_formKey.currentState!.validate() && _selectedFluidId != null) {
      _formKey.currentState!.save();
      
      setState(() {
        _isLoading = true;
      });

      try {
        await RefreshTokenIfExpired();
        final accessToken = await storage.read(key: 'accessToken');
        
        // Format date as YYYY-MM-DD for API
        final formattedDate = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
        
        final url = Uri.parse('$apiUrl/user/planner/add-fluid');
        print('Adding fluid with ID: $_selectedFluidId, amount: $_quantity, date: $formattedDate');
        
        final response = await http.post(
          url,
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            "date": formattedDate,
            "_id": _selectedFluidId,
            "amount": _quantity
          }),
        );
        
        print('Add fluid response status: ${response.statusCode}');
        print('Add fluid response body: ${response.body}');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fluid added successfully')),
          );
          Navigator.pop(context, true);
        } else {
          print('Failed to add fluid: ${response.statusCode}');
          print('Response: ${response.body}');
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add fluid: ${response.statusCode}')),
          );
        }
      } catch (e) {
        print('Error in _addFluid: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text("${loc.addFluid} - ${dateFormatter.format(widget.selectedDate)}"),
        backgroundColor: Colors.green.shade50,
        elevation: 0,
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.fluidType, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 8),
                _fluids.isEmpty
                  ? Column(
                      children: [
                        Text('No fluids available', style: TextStyle(color: Colors.red)),
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _fetchFluids,
                          icon: Icon(Icons.refresh),
                          label: Text('Refresh Fluids'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ],
                    )
                  : Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _fluids.length,
                        itemBuilder: (context, index) {
                          final fluid = _fluids[index];
                          // Make sure we're working with a Map
                          if (fluid is! Map) {
                            print('Warning: fluid at index $index is not a Map: $fluid');
                            return ListTile(
                              title: Text('Invalid fluid data'),
                              subtitle: Text('Data format error'),
                            );
                          }
                          
                          // Safely access data
                          final name = fluid['name'] ?? 'Unknown';
                          final id = fluid['_id'] ?? '';
                          final kcal = fluid['kcalPortion'] ?? 0;
                          
                          return RadioListTile<String>(
                            title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$kcal kcal per 100g'),
                                // Safely create the nutrition text with null checks
                                _buildNutrientText(fluid),
                              ],
                            ),
                            value: id,
                            groupValue: _selectedFluidId,
                            onChanged: (value) {
                              setState(() {
                                _selectedFluidId = value;
                              });
                            },
                            activeColor: Colors.green,
                            secondary: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Icon(Icons.water_drop, color: Colors.blue),
                            ),
                          );
                        },
                      ),
                    ),
                const SizedBox(height: 16),
                Text(loc.quantity, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                Wrap(
                  spacing: 8.0,
                  children: [
                    ChoiceChip(
                      label: Text('120 ml'),
                      selected: _quantity == 120,
                      onSelected: (selected) {
                        setState(() {
                          _quantity = 120;
                        });
                      },
                      selectedColor: Colors.blue.shade100,
                    ),
                    ChoiceChip(
                      label: Text('250 ml'),
                      selected: _quantity == 250,
                      onSelected: (selected) {
                        setState(() {
                          _quantity = 250;
                        });
                      },
                      selectedColor: Colors.blue.shade100,
                    ),
                    ChoiceChip(
                      label: Text('330 ml'),
                      selected: _quantity == 330,
                      onSelected: (selected) {
                        setState(() {
                          _quantity = 330;
                        });
                      },
                      selectedColor: Colors.blue.shade100,
                    ),
                    ChoiceChip(
                      label: Text('500 ml'),
                      selected: _quantity == 500,
                      onSelected: (selected) {
                        setState(() {
                          _quantity = 500;
                        });
                      },
                      selectedColor: Colors.blue.shade100,
                    ),
                    ChoiceChip(
                      label: Text('1 L'),
                      selected: _quantity == 1000,
                      onSelected: (selected) {
                        setState(() {
                          _quantity = 1000;
                        });
                      },
                      selectedColor: Colors.blue.shade100,
                    ),
                    ChoiceChip(
                      label: Text(loc.customQuantity),
                      selected: _quantity == -1,
                      onSelected: (selected) {
                        setState(() {
                          _quantity = -1;
                        });
                      },
                      selectedColor: Colors.blue.shade100,
                    ),
                  ],
                ),
                if (_quantity == -1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextFormField(
                      controller: _customQuantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.enterCustomQuantity,
                        hintText: loc.quantityInMl,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_drink, color: Colors.blue),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return loc.pleaseEnterQuantity;
                        }
                        final int? quantity = int.tryParse(value);
                        if (quantity == null || quantity <= 0) {
                          return loc.pleaseEnterValidNumber;
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _quantity = int.parse(value!);
                      },
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.cancel, color: Colors.red),
                      label: Text(loc.cancel, style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _selectedFluidId == null ? null : _addFluid,
                      icon: Icon(Icons.check, color: Colors.white),
                      label: Text(loc.add, style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    );
  }
}