import 'package:flutter/material.dart';

Widget loading() {
  return Container(
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
        child: Center(
    child: CircularProgressIndicator(),
  ));
}