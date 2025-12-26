// lib/screens/seller_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:my_test_app/widgets/seller/seller_sidebar.dart';
import 'package:my_test_app/screens/seller/seller_overview_screen.dart';
import 'package:my_test_app/services/user_session.dart'; // 🎯 استيراد الجلسة
import 'package:sizer/sizer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class SellerScreen extends StatefulWidget {
  static const String routeName = '/sellerhome';
  const SellerScreen({super.key});

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  String _activeRoute = 'نظرة عامة';
  Widget _activeScreen = const SellerOverviewScreen();
  
  // 🔔 قائمة لتخزين آخر 5 إشعارات محلياً
  final List<Map<String, String>> _recentNotifications = [];

  void _selectMenuItem(String route, Widget screen) {
    setState(() {
      _activeRoute = route;
      _activeScreen = screen;
    });
  }

  void _handleLogout() async {
    UserSession.clear(); // مسح الجلسة المركزية
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _setupNotifications() async {
    var status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // الاستماع للإشعارات والتطبيق مفتوح
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _addNewNotification(
          message.notification!.title ?? "تنبيه",
          message.notification!.body ?? "",
        );
      }
    });
  }

  // 🎯 إضافة الإشعار للقائمة وحفظ آخر 5 فقط
  void _addNewNotification(String title, String body) {
    setState(() {
      _recentNotifications.insert(0, {
        'title': title,
        'body': body,
        'time': "${DateTime.now().hour}:${DateTime.now().minute}"
      });
      if (_recentNotifications.length > 5) {
        _recentNotifications.removeLast();
      }
    });
    _showNotificationDialog(title, body);
  }

  // 🎯 نافذة عرض قائمة الإشعارات الخمسة الأخيرة
  void _showNotificationsList() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("آخر التنبيهات", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.green)),
              const Divider(),
              if (_recentNotifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Text("لا توجد إشعارات جديدة حالياً"),
                ),
              ..._recentNotifications.map((noti) => ListTile(
                    leading: const Icon(Icons.notifications_active, color: Colors.orange),
                    title: Text(noti['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(noti['body']!),
                    trailing: Text(noti['time']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  )),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(children: [const Icon(Icons.stars, color: Colors.green), const SizedBox(width: 10), Text(title)]),
        content: Text(body),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('فهمت'))],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _setupNotifications();
    });

    Future.microtask(() {
      if (!mounted) return;
      final controller = Provider.of<SellerDashboardController>(context, listen: false);
      // استخدام ownerId من الجلسة لضمان جلب بيانات المورد الصحيح (حتى لو كان الداخل موظف)
      controller.loadDashboardData(UserSession.ownerId ?? controller.sellerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SellerDashboardController>(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        centerTitle: true,
        toolbarHeight: 8.h,
        title: Text(_activeRoute, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 28),
                onPressed: _showNotificationsList, // 🎯 فتح القائمة المنسدلة
              ),
              if (_recentNotifications.isNotEmpty) // نقطة تنبيه حمراء إذا وجد إشعارات جديدة
                Positioned(
                  top: 15,
                  right: 15,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  ),
                )
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _activeScreen,
      drawer: SellerSidebar(
        userData: SellerUserData(fullname: controller.data.sellerName),
        onMenuSelected: _selectMenuItem,
        activeRoute: _activeRoute,
        onLogout: _handleLogout,
        newOrdersCount: controller.data.newOrdersCount,
        sellerId: UserSession.ownerId ?? controller.sellerId, // 🎯 تمرير الـ ownerId الصحيح
      ),
    );
  }
}

