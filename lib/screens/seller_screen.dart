// lib/screens/seller_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:my_test_app/widgets/seller/seller_sidebar.dart';
import 'package:my_test_app/screens/seller/seller_overview_screen.dart';
import 'package:my_test_app/services/user_session.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
// 🎯 استيراد ودجت الشات الجديدة
import 'package:my_test_app/widgets/chat_support_widget.dart'; 

class SellerScreen extends StatefulWidget {
  static const String routeName = '/sellerhome';
  const SellerScreen({super.key});

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  String _activeRoute = 'نظرة عامة';
  Widget _activeScreen = const SellerOverviewScreen();
  final List<Map<String, String>> _recentNotifications = [];

  void _selectMenuItem(String route, Widget screen) {
    setState(() {
      _activeRoute = route;
      _activeScreen = screen;
    });
  }

  void _handleLogout() async {
    UserSession.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  // ... (بقيت الدالات الخاصة بالإشعارات كما هي بدون تغيير) ...
  void _setupNotifications() async { /* كود الإشعارات */ }
  void _addNewNotification(String title, String body) { /* كود إضافة إشعار */ }
  void _showNotificationsList() { /* كود عرض القائمة */ }
  void _showNotificationDialog(String title, String body) { /* كود الديالوج */ }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _setupNotifications();
    });
    Future.microtask(() {
      if (!mounted) return;
      final controller = Provider.of<SellerDashboardController>(context, listen: false);
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
                onPressed: _showNotificationsList,
              ),
              if (_recentNotifications.isNotEmpty)
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
      
      // 🚀 إضافة زر الشات العائم هنا ليظهر في كل الصفحات الداخلية
      floatingActionButton: FloatingActionButton(
        heroTag: "seller_main_chat",
        backgroundColor: const Color(0xff28a745),
        elevation: 4,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent, // لجعل الحواف الدائرية تظهر بشكل جيد
            builder: (context) => const ChatSupportWidget(),
          );
        },
        child: const Icon(Icons.support_agent, color: Colors.white, size: 32),
      ),

      body: _activeScreen,
      drawer: SellerSidebar(
        userData: SellerUserData(fullname: controller.data.sellerName),
        onMenuSelected: _selectMenuItem,
        activeRoute: _activeRoute,
        onLogout: _handleLogout,
        newOrdersCount: controller.data.newOrdersCount,
        sellerId: UserSession.ownerId ?? controller.sellerId,
      ),
    );
  }
}

