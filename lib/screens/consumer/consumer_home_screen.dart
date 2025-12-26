// lib/screens/consumer/consumer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
import 'package:my_test_app/services/consumer_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🎯 إضافة الإشعارات
import 'package:cloud_firestore/cloud_firestore.dart'; // 🎯 إضافة الفايرستور للتوكن
// 🎯 استيراد ودجت الشات
import 'package:my_test_app/widgets/chat_support_widget.dart'; 

class ConsumerHomeScreen extends StatefulWidget {
  static const routeName = '/consumerHome';
  const ConsumerHomeScreen({super.key});

  @override
  State<ConsumerHomeScreen> createState() => _ConsumerHomeScreenState();
}

class _ConsumerHomeScreenState extends State<ConsumerHomeScreen> {
  final ConsumerDataService dataService = ConsumerDataService();

  @override
  void initState() {
    super.initState();
    _setupNotifications(); // 🚀 طلب الإذن فور الدخول
  }

  // 🎯 دالة إعداد الإشعارات للمستهلك
  Future<void> _setupNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    // طلب إذن الإشعارات
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // الحصول على التوكن وحفظه في مستند المستهلك
      String? token = await messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // إضافة الـ Drawer هنا ليعمل مع زر المنيو
      drawer: const ConsumerSideMenu(),
      
      // 1. الـ AppBar مع تمرير الـ Context الصحيح لفتح المنيو
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Builder(
          builder: (context) => ConsumerCustomAppBar(
            userName: user?.displayName ?? 'مستخدم',
            userPoints: 0,
            onMenuPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2. شريط الرادار (اكتشف ما حولك)
              const SizedBox(height: 10),
              const ConsumerSearchBar(),

              // 3. قسم الأقسام المميزة
              const ConsumerSectionTitle(title: 'الأقسام المميزة'),
              FutureBuilder<List<ConsumerCategory>>(
                future: dataService.fetchMainCategories(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 130,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF43A047))),
                    );
                  }
                  final categories = snapshot.data ?? [];
                  return ConsumerCategoriesBanner(categories: categories);
                },
              ),
              const SizedBox(height: 10),

              // 4. قسم العروض الحصرية
              const ConsumerSectionTitle(title: 'أحدث العروض الحصرية'),
              FutureBuilder<List<ConsumerBanner>>(
                future: dataService.fetchPromoBanners(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF43A047))),
                    );
                  }
                  final banners = snapshot.data ?? [];
                  return ConsumerPromoBanners(banners: banners, height: 220);
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      
      // 5. شريط التنقل السفلي
      bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: 0),

      // 🚀 6. إضافة زر الشات الذكي للمستهلك
      floatingActionButton: FloatingActionButton(
        heroTag: "consumer_chat_btn", // تاغ فريد للمستهلك
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const ChatSupportWidget(),
          );
        },
        backgroundColor: const Color(0xFF43A047), // لون المستهلك الأخضر
        child: const Icon(Icons.support_agent, color: Colors.white, size: 30),
      ),
    );
  }
}

