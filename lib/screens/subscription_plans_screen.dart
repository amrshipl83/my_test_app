import 'package:flutter/material.dart';

class SubscriptionPlansScreen extends StatelessWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('باقات الاشتراك المميزة', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFFB21F2D),
      ),
      body: const Center(
        child: Text(
          'شاشة الباقات - سيتم ربطها بـ Firestore قريباً',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 16),
        ),
      ),
    );
  }
}
