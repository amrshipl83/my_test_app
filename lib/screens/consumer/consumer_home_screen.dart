// lib/screens/consumer/consumer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
import 'package:my_test_app/services/consumer_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // جلب المستخدم الحقيقي

class ConsumerHomeScreen extends StatelessWidget {
  static const routeName = '/consumerHome';
  
  ConsumerHomeScreen({super.key});

  final ConsumerDataService dataService = ConsumerDataService();

  @override
  Widget build(BuildContext context) {
    // جلب المستخدم الحالي بدلاً من MockUserId
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // 🎯 استخدام drawer بدلاً من endDrawer ليعمل مع RTL بشكل صحيح من اليمين
      drawer: const ConsumerSideMenu(),
      
      // 1. شريط التنقل العلوي
      appBar: ConsumerCustomAppBar(
        userName: user?.displayName ?? 'مستخدم', // الاسم سيحدث تلقائياً من الـ Stream في الودجت
        userPoints: 0,
        onMenuPressed: () {
          // فتح القائمة الجانبية (Drawer) يدوياً
          Builder(builder: (context) {
            return Scaffold.of(context).openDrawer();
          });
        },
      ),

      // 2. محتوى الشاشة مغلف بـ SafeArea لمنع التداخل مع شريط الهاتف
      body: SafeArea( 
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🎯 شريط البحث - قلب التطبيق
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: ConsumerSearchBar(),
              ),

              // 3. الأقسام المميزة مع Firebase
              const ConsumerSectionTitle(title: 'الأقسام المميزة'),
              FutureBuilder<List<ConsumerCategory>>(
                future: dataService.fetchMainCategories(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  final categories = snapshot.data ?? [];
                  if (categories.isEmpty || snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: Text('لا توجد أقسام نشطة حالياً.')),
                    );
                  }
                  return ConsumerCategoriesBanner(categories: categories);
                },
              ),

              // 4. العروض الحصرية (البانر الإعلاني)
              const ConsumerSectionTitle(title: 'أحدث العروض الحصرية'),
              FutureBuilder<List<ConsumerBanner>>(
                future: dataService.fetchPromoBanners(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ));
                  }
                  final banners = snapshot.data ?? [];
                  if (banners.isEmpty || snapshot.hasError) {
                    // إذا لم توجد عروض، نعرض مساحة فارغة بسيطة
                    return const SizedBox(height: 20);
                  }
                  return ConsumerPromoBanners(banners: banners);
                },
              ),

              const SizedBox(height: 30), // مساحة إضافية في الأسفل
            ],
          ),
        ),
      ),

      // 5. شريط التنقل السفلي
      bottomNavigationBar: const ConsumerFooterNav(cartCount: 3, activeIndex: 0),
    );
  }
}
