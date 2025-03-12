import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class EditFluidPage extends StatefulWidget {
  final DateTime selectedDate;
  const EditFluidPage({Key? key, required this.selectedDate}) : super(key: key);

  @override
  _EditFluidPageState createState() => _EditFluidPageState();
}

class _EditFluidPageState extends State<EditFluidPage> {
  final _formKey = GlobalKey<FormState>();
  String _fluidName = '';
  int _quantity = 0;
  
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final dateFormatter = DateFormat('dd/MM/yyyy');
    
    return Scaffold(
      appBar: AppBar(
        title: Text("${loc.editFluid} - ${dateFormatter.format(widget.selectedDate)}"),
        backgroundColor: Colors.green.shade50,
        elevation: 0,
      ),
      body: Container(
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
              TextFormField(
                decoration: InputDecoration(
                  labelText: loc.fluidName,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterFluidName;
                  }
                  return null;
                },
                onSaved: (value) {
                  _fluidName = value!;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: "${loc.quantity} (ml)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterQuantity;
                  }
                  if (int.tryParse(value) == null) {
                    return loc.pleaseEnterValidNumber;
                  }
                  return null;
                },
                onSaved: (value) {
                  _quantity = int.parse(value!);
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: Text(loc.cancel),
                  ),
                  ElevatedButton(
                    onPressed: _saveFluid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: Text(loc.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveFluid() {
    final loc = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Here you would typically save the fluid to your data source
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.fluidSaved(_fluidName, _quantity))),
      );
      Navigator.pop(context);
    }
  }
}
