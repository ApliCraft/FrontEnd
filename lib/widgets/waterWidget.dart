import 'package:flutter/material.dart';

Container waterWidget(context) {
  return Container(
    margin: const EdgeInsets.fromLTRB(5, 0, 5, 0),
    width: 160,
    height: 160,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Color(0xff1D1617).withOpacity(0.05),
          blurRadius: 40,
          spreadRadius: 0.0,
        )
      ],
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.blue, width: 1),
    ),
    child: Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(
              Icons.water_drop,
              size: 30,
              color: Colors.blue,
            ),
            Text('Water',
                style: TextStyle(
                    fontSize: 25,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        // Chwilowo jest const potem zmienić jak będzie działało zapisywanie wody
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text('1.5L/2L',
                style: TextStyle(
                    fontSize: 20,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              onPressed: () {
                print('Drink water');
              },
              child: const Text('Add water',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        )
      ],
    ),
  );
}