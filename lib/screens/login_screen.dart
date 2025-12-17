import 'package:flutter/material.dart';
import 'package:my_test_app/widgets/login_form_widget.dart';
import 'package:flutter/gestures.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  static const String routeName = '/login';

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF2D9E68);
    const Color lightBg = Color(0xFFF8FAF9);

    return Scaffold(
      backgroundColor: lightBg,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: CircleAvatar(radius: 150, backgroundColor: primaryGreen.withOpacity(0.05)),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // تم حذف اللوجو بناءً على طلبك لمنع أخطاء الـ Assets
                    const Icon(Icons.account_circle, size: 100, color: primaryGreen), 
                    const SizedBox(height: 24),
                    const Text(
                      'أهلاً بك في أكسب',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: const LoginFormWidget(),
                    ),
                    const SizedBox(height: 32),
                    const _FooterWidget(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterWidget extends StatelessWidget {
  const _FooterWidget();
  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'ليس لديك حساب؟ ',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
        children: [
          TextSpan(
            text: 'إنشاء حساب جديد',
            style: TextStyle(color: const Color(0xFF2D9E68), fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()..onTap = () => Navigator.of(context).pushNamed('/register'),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
