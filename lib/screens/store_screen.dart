// lib/screens/store_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:my_test_app/services/store_data_service.dart'; // الخدمة المساعدة
import 'package:my_test_app/widgets/store_widgets.dart'; // المكونات المرئية
import 'package:my_test_app/helpers/auth_service.dart'; // لإدارة تسجيل الخروج

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  static const String routeName = '/buyer-home'; // مسار الشاشة في main.dart

  @override
  Widget build(BuildContext context) {
    // 💡 استخدام ChangeNotifierProvider لتهيئة الخدمة 
    // وجعلها متاحة لجميع المكونات الفرعية التي تحتاج البيانات.
    return ChangeNotifierProvider(
      create: (context) => StoreDataService()..initializeData(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          // ⭐️ الشريط الجانبي (Sidebar)
          endDrawer: const StoreSidebar(), 
          
          // ⭐️ جسم الشاشة الرئيسية
          body: Consumer<StoreDataService>(
            builder: (context, dataService, child) {
              final user = dataService.loggedUser;

              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return <Widget>[
                    // ⭐️ الـ Header العلوي (Top-Header)
                    StoreTopHeader(
                      fullname: user?['fullname'] ?? 'زائر',
                      isDarkTheme: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ];
                },
                body: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 20),
                      // ⭐️ قسم البانرات (Slider)
                      const BannerSliderSection(), 
                      const SizedBox(height: 20),
                      // ⭐️ عنوان قسم الأقسام
                      StoreSectionTitle(
                        title: 'الأقسام الرئيسية',
                        icon: FontAwesomeIcons.tags,
                      ),
                      // ⭐️ شبكة الأقسام (Categories Grid)
                      CategoriesGrid(
                        categories: dataService.categories,
                        isLoading: dataService.isLoading,
                        errorMessage: dataService.errorMessage,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // ⭐️ شريط التنقل السفلي (Mobile Nav)
          bottomNavigationBar: StoreMobileNav(),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// مكون Sidebar (تم نقله هنا لتسهيل استخدام endDrawer)
// ----------------------------------------------------
class StoreSidebar extends StatelessWidget {
  const StoreSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<StoreDataService>(context);
    final deliveryLinksVisible = dataService.deliveryLinksVisible;
    final newOrdersCount = dataService.newOrdersCount;
    final user = dataService.loggedUser;

    return Drawer(
      child: Container(
        color: Theme.of(context).cardColor, // استخدام لون البطاقة ليتناسب مع الثيم
        child: Column(
          children: <Widget>[
            // 💡 رأس الشريط الجانبي
            const SidebarHeaderWidget(),
            
            // 💡 عناصر التنقل الأساسية
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  SidebarItem(
                    title: 'التجار',
                    icon: FontAwesomeIcons.storeAlt,
                    onTap: () => Navigator.of(context).pushNamed('/search-merchants'), // مسار Traders.html
                  ),
                  SidebarItem(
                    title: 'محفظتى',
                    icon: FontAwesomeIcons.wallet,
                    onTap: () => Navigator.of(context).pushNamed('/wallet'), // مسار وهمي
                  ),
                  // 💡 عناصر الدليفري (تعتمد على حالة الـ Service)
                  if (deliveryLinksVisible)
                    SidebarItem(
                      title: 'خدمة الدليفري',
                      icon: FontAwesomeIcons.truck,
                      onTap: () => Navigator.of(context).pushNamed('/deliverySettings', arguments: {
                         'ownerId': user?['id'], 
                         'userName': user?['fullname'], 
                         'userPhone': user?['phone'] // افترض وجود حقل الهاتف
                       }), 
                    ),
                   if (dataService.isDeliveryActive)
                    SidebarItem(
                      title: 'إدارة أسعار الدليفري',
                      icon: FontAwesomeIcons.handHoldingDollar,
                      onTap: () => Navigator.of(context).pushNamed('/deliveryOffer', arguments: {
                         'ownerId': user?['id'], 
                         'userName': user?['fullname']
                       }),
                    ),

                  // 💡 طلبات الدليفري مع العداد
                  if (dataService.isDeliveryActive)
                    SidebarItem(
                      title: 'طلبات الدليفري',
                      icon: FontAwesomeIcons.boxOpen,
                      count: newOrdersCount,
                      onTap: () => dataService.openOrdersModal(context),
                    ),
                  
                  // عناصر أخرى...
                  SidebarItem(
                    title: 'حسابي',
                    icon: FontAwesomeIcons.user,
                    onTap: () => Navigator.of(context).pushNamed('/user-details'), // مسار My details.html
                  ),
                  SidebarItem(
                    title: 'من نحن',
                    icon: FontAwesomeIcons.infoCircle,
                    onTap: () => Navigator.of(context).pushNamed('/about'), // مسار About.html
                  ),
                  SidebarItem(
                    title: 'الخصوصية والاستخدام',
                    icon: FontAwesomeIcons.fileContract,
                    onTap: () => Navigator.of(context).pushNamed('/privacy'),
                  ),
                ],
              ),
            ),
            
            // 💡 زر تسجيل الخروج
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.signOutAlt, size: 18),
                label: const Text('تسجيل الخروج'),
                onPressed: () {
                  AuthService().signOut(context); // استخدام خدمة المصادقة
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            
            // 💡 روابط التواصل الاجتماعي
            const SocialLinksWidget(),
          ],
        ),
      ),
    );
  }
}
