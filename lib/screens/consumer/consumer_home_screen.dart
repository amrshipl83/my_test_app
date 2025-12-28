// lib/screens/consumer/consumer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
import 'package:my_test_app/services/consumer_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/widgets/chat_support_widget.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';

class ConsumerHomeScreen extends StatefulWidget {
  static const routeName = '/consumerHome';
  const ConsumerHomeScreen({super.key});

  @override
  State<ConsumerHomeScreen> createState() => _ConsumerHomeScreenState();
}

class _ConsumerHomeScreenState extends State<ConsumerHomeScreen> {
  final ConsumerDataService dataService = ConsumerDataService();
  final Color softGreen = const Color(0xFF66BB6A);
  final Color darkGreenText = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
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
      backgroundColor: const Color(0xFFFBFBFB),
      drawer: const ConsumerSideMenu(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 75,
        iconTheme: IconThemeData(color: softGreen),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              "مرحباً بك، ${user?.displayName ?? 'مستخدم'}",
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            Text(
              "AMR",
              style: TextStyle(color: darkGreenText, fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.orange, size: 18),
                const SizedBox(width: 4),
                Text("0", style: TextStyle(color: darkGreenText, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 105), // مساحة لزر الرادار
                  
                  // 🎯 إضافة بنر "ابعتلي حد" (خدمة التوصيل الحر)
                  _buildFreeDeliveryBanner(),

                  const ConsumerSectionTitle(title: 'الأقسام المميزة'),
                  FutureBuilder<List<ConsumerCategory>>(
                    future: dataService.fetchMainCategories(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SizedBox(
                          height: 130,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: softGreen)),
                        );
                      }
                      return ConsumerCategoriesBanner(categories: snapshot.data ?? []);
                    },
                  ),

                  const SizedBox(height: 10),
                  const ConsumerSectionTitle(title: 'أحدث العروض الحصرية'),
                  FutureBuilder<List<ConsumerBanner>>(
                    future: dataService.fetchPromoBanners(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: softGreen)),
                        );
                      }
                      return ConsumerPromoBanners(banners: snapshot.data ?? [], height: 220);
                    },
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
            Positioned(
              top: 15,
              left: 15,
              right: 15,
              child: _buildSmartRadarButton(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: 0),
      floatingActionButton: FloatingActionButton(
        heroTag: "consumer_chat_btn",
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const ChatSupportWidget(),
          );
        },
        backgroundColor: softGreen,
        child: const Icon(Icons.support_agent, color: Colors.white, size: 30),
      ),
    );
  }

  // 🚚 ويدجت بنر "ابعتلي حد" الجديد
  Widget _buildFreeDeliveryBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // اللون البرتقالي المميز لخدمة المندوب الحر
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // أيقونة تعبيرية لخدمة النقل
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delivery_dining, color: Colors.white, size: 35),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ابعتلي حد",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "اطلب مندوب حر لنقل أغراضك فوراً",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // زر الأكشن
            ElevatedButton(
              onPressed: () {
                // فتح شاشة الطلب الحر مباشرة
                Navigator.pushNamed(context, '/delivery-offers'); // المسار المسئول عن المندوب الحر
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 15),
              ),
              child: const Text(
                "اطلب الآن",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartRadarButton() {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [softGreen, const Color(0xFF4CAF50)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: softGreen.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () {
            Navigator.pushNamed(context, ConsumerStoreSearchScreen.routeName);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.radar, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "اكتشف المحلات القريبة",
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "تفعيل رادار البحث الذكي",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.my_location, color: Colors.white, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

