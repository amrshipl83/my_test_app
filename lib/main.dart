import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:my_test_app/firebase_options.dart';
import 'package:sizer/sizer.dart';

void main() async {
  // تعطيل تسجيل الأخطاء مؤقتاً لضمان عدم التداخل
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // حتى لو فشل الفايربيس لا تجعل التطبيق يغلق
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          // إلغاء الثيمات المعقدة والخطوط الخارجية مؤقتاً
          theme: ThemeData(primarySwatch: Colors.green),
          home: Scaffold(
            appBar: AppBar(title: const Text("نسخة اختبار الاستقرار")),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 100, color: Colors.green),
                  const SizedBox(height: 20),
                  const Text("إذا رأيت هذه الشاشة، فالمشكلة في الخطوط أو الثيمات!"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // سنحاول الانتقال لشاشة الدخول الأصلية من هنا لاحقاً
                    },
                    child: const Text("استمرار"),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

