import 'package:flutter/material.dart';

Container frigdeWidget(context) {
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
      border: Border.all(color: Colors.grey, width: 1),
    ),
    child: Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(
              Icons.kitchen,
              size: 30,
              color: Colors.grey,
            ),
            Text('Fridge',
                style: TextStyle(
                    fontSize: 25,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Your fridge\n  is empty',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
              ),
              onPressed: () {
                print('Fridge');
              },
              child: const Text('Add products',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        )
      ],
    ),
  );
}