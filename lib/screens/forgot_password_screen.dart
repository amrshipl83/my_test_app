// lib/screens/forgot_password_screen.dart

import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نسيت كلمة المرور')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(); // العودة إلى شاشة الدخول
          },
          child: const Text('العودة لتسجيل الدخول'),
        ),
      ),
    );
  }
}
