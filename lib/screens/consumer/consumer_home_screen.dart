import 'package:flutter/material.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
import 'package:my_test_app/services/consumer_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart';

class ConsumerHomeScreen extends StatelessWidget {
  static const routeName = '/consumerHome';
  ConsumerHomeScreen({super.key});

  final ConsumerDataService dataService = ConsumerDataService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // خلفية فاتحة تبرز العناصر
      drawer: const ConsumerSideMenu(),
      
      // 1. الـ AppBar ثابت وواضح بألوان الهوية
      appBar: ConsumerCustomAppBar(
        userName: user?.displayName ?? 'مستخدم',
        userPoints: 1000,
        onMenuPressed: () => Scaffold.of(context).openDrawer(),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2. شريط الرادار (تصميم بارز وواضح بدون تكدس)
              const SizedBox(height: 15),
              const ConsumerSearchBar(), 

              const SizedBox(height: 10),

              // 3. قسم الأقسام المميزة (خطوط واضحة وأحجام مريحة)
              const ConsumerSectionTitle(title: 'الأقسام المميزة'),
              FutureBuilder<List<ConsumerCategory>>(
                future: dataService.fetchMainCategories(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 140,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  final categories = snapshot.data ?? [];
                  return ConsumerCategoriesBanner(categories: categories);
                },
              ),

              const SizedBox(height: 15),

              // 4. قسم العروض (يملأ المساحة السفلية بذكاء)
              const ConsumerSectionTitle(title: 'أحدث العروض الحصرية'),
              FutureBuilder<List<ConsumerBanner>>(
                future: dataService.fetchPromoBanners(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  final banners = snapshot.data ?? [];
                  // ارتفاع 250 ليملأ الشاشة ويظهر تفاصيل المنتج
                  return ConsumerPromoBanners(banners: banners, height: 250);
                },
              ),

              const SizedBox(height: 40), // مساحة للتنفس قبل الـ NavigationBar
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ConsumerFooterNav(cartCount: 3, activeIndex: 0),
    );
  }
}
