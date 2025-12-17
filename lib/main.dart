import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red, // لون فاقع لنعرف أن التطبيق فتح
        body: Center(
          child: Text(
            "CRASH FIXED!", 
            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ),
  );
}
