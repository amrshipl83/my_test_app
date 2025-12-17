import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:my_test_app/firebase_options.dart';
import 'package:my_test_app/screens/login_screen.dart'; // استيراد صفحة الدخول
import 'package:sizer/sizer.dart'; // لدعم التصميم المتجاوب

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // معالجة الخطأ بصمت لضمان استمرارية التشغيل
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // استخدام Sizer لجعل التصاميم متجاوبة كما في خطة التحسين [cite: 16-12-2025]
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'أكسب',
          theme: ThemeData(
            primaryColor: const Color(0xFF2D9E68),
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D9E68)),
            useMaterial3: true,
          ),
          // الصفحة الأولى للمراجعة والتحسين [cite: 16-12-2025]
          home: const LoginScreen(), 
          
          // تعريف المسارات لتجنب الكراش عند التنقل
          routes: {
            '/login': (context) => const LoginScreen(),
            // أضف المسارات الأخرى (Register, ForgotPassword) هنا لاحقاً عند نقل ملفاتها
          },
        );
      },
    );
  }
}
