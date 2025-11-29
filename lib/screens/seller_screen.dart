// lib/screens/seller_screen.dart (النسخة النهائية والمُصححة بالكامل)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:my_test_app/widgets/seller/seller_sidebar.dart';
import 'package:my_test_app/models/seller_dashboard_data.dart'; 

// 🟢🟢 استيراد شاشة الكارتات الجديدة (SellerOverviewScreen) 🟢🟢
import 'package:my_test_app/screens/seller/seller_overview_screen.dart';


class SellerScreen extends StatefulWidget {
  // 🟢 routeName لحل خطأ main.dart
  static const String routeName = '/sellerhome';

  const SellerScreen({super.key});

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  // 1. تعريف القائمة والمسار النشط
  String _activeRoute = 'نظرة عامة';
  // 🟢 تعيين شاشة الكارتات الجديدة كشاشة افتراضية (بدلاً من الشاشة الوهمية) 🟢
  Widget _activeScreen = const SellerOverviewScreen();

  // 2. معالج التبديل بين شاشات القائمة الجانبية
  void _selectMenuItem(String route, Widget screen) {
    setState(() {
      _activeRoute = route;
      _activeScreen = screen;
    });
  }

  // 3. دالة تسجيل الخروج المُعدلة
  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();

    // 🛑 الأهم: حذف المفتاح الذي يستخدمه AuthWrapper في main.dart 🛑
    await prefs.remove('loggedUser'); 
    
    // حذف المفاتيح الأخرى للاحتياط
    await prefs.remove('userToken');
    await prefs.remove('userRole'); 

    // التوجيه إلى المسار الرئيسي
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  void initState() {
    super.initState();
    // 🟢🟢 الكود المعدل لتشغيل دالة جلب البيانات فوراً 🟢🟢
    // هذا يضمن أن البيانات تبدأ بالتحميل بمجرد فتح الشاشة
    Future.microtask(() {
        final controller = Provider.of<SellerDashboardController>(context, listen: false);
        // التحقق لضمان عدم إعادة تشغيل الجلب إذا كان قيد التشغيل بالفعل
        if (!controller.isLoading) {
            controller.loadDashboardData(controller.sellerId);
        }
    });
  }


  @override
  Widget build(BuildContext context) {
    // قراءة الكنترولر للحصول على البيانات اللازمة للشريط الجانبي
    final controller = Provider.of<SellerDashboardController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_activeRoute),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),

      // 5. محتوى الشاشة (الـ Widget النشط)
      body: _activeScreen,

      // 6. الشريط الجانبي (Drawer)
      drawer: SellerSidebar(
        // 🟢 تمرير بيانات البائع (الاسم)
        userData: SellerUserData(fullname: controller.data.sellerName),

        // 🟢 تمرير الدالة للتحكم بالمسار النشط
        onMenuSelected: _selectMenuItem,
        activeRoute: _activeRoute,

        // 🟢 تمرير دالة الخروج (onLogout)
        onLogout: _handleLogout,

        // تمرير الإحصائيات والمعلومات
        newOrdersCount: controller.data.newOrdersCount,
        sellerId: controller.sellerId,
        hasWriteAccess: true,
      ),
    );
  }
}

