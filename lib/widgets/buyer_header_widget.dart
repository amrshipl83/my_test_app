// المسار: lib/widgets/buyer_header_widget.dart
import 'package:flutter/material.dart';
// لم نعد نحتاج إلى استيراد LucideIcons
// import 'package:lucide_icons/lucide_icons.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// تعريفات Firebase (مضمنة هنا لجعله وحدة مستقلة)
final FirebaseAuth _auth = FirebaseAuth.instance;

class BuyerHeaderWidget extends StatelessWidget {
  final VoidCallback onMenuToggle;
  final String userName;
  final bool menuNotificationDotActive;
  final VoidCallback onLogout;

  const BuyerHeaderWidget({
    super.key,
    required this.onMenuToggle,
    required this.userName,
    this.menuNotificationDotActive = false,
    required this.onLogout,
  });

  // --- بناء المودال المؤقتة ---
  static void _showNewOrdersModal(BuildContext context) {
    Navigator.pop(context); // إغلاق الـ Drawer أولاً
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('طلبات دليفري جديدة (مودال مؤقت)'),
            content: const Text('هنا ستظهر قائمة مختصرة بطلبات الدليفري الجديدة.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // توجيه لصفحة افتراضية
                  Navigator.of(context).pushNamed('/conOrders');
                },
                child: const Text('عرض كل الطلبات'),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- بناء القائمة الجانبية (Sidebar / Drawer) ---
  static Widget buildSidebar({
    required BuildContext context,
    required VoidCallback onLogout,
    int newOrdersCount = 0,
    bool deliveryIsActive = true,
    bool deliverySettingsAvailable = false,
    bool deliveryPricesAvailable = true,
  }) {
    void navigateTo(String route) {
      Navigator.pop(context);
      Navigator.of(context).pushNamed(route);
    }

    final List<Map<String, dynamic>> navItems = [
      // ✅ أيقونة Material: واجهة متجر دائرية
      {'title': 'التجار', 'icon': Icons.storefront_rounded, 'route': '/traders'},
      // ✅ أيقونة Material: محفظة دائرية
      {'title': 'محفظتى', 'icon': Icons.account_balance_wallet_rounded, 'route': '/goals'},
      // ✅ أيقونة Material: شاحنة دائرية
      if (deliverySettingsAvailable)
        {'title': 'خدمة الدليفري', 'icon': Icons.local_shipping_rounded, 'route': '/deliverySettings'},
      // ✅ أيقونة Material: تغيير السعر دائرية (بديل Landmark)
      if (deliveryPricesAvailable)
        {'title': 'إدارة أسعار الدليفري', 'icon': Icons.price_change_rounded, 'route': '/deliveryPrices'},
      if (deliveryIsActive)
        {
          // ✅ أيقونة Material: حقيبة تسوق دائرية (بديل Package)
          'title': 'طلبات الدليفري',
          'icon': Icons.shopping_bag_rounded,
          'onTap': () => _showNewOrdersModal(context),
          'notificationCount': newOrdersCount,
        },
      // ✅ أيقونة Material: حساب دائري
      {'title': 'حسابي', 'icon': Icons.account_circle_rounded, 'route': '/myDetails'},
      // ✅ أيقونة Material: معلومات دائرية
      {'title': 'من نحن', 'icon': Icons.info_outline_rounded, 'route': '/about'},
      // ✅ أيقونة Material: ملف دائرية
      {'title': 'الخصوصية والاستخدام', 'icon': Icons.description_rounded, 'route': '/privacy'},
    ];

    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2c3e50), Color(0xFF4CAF50)], begin: Alignment.centerRight, end: Alignment.centerLeft)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisAlignment: MainAxisAlignment.center,
                // ✅ أيقونة Material: متجر
                children: [Icon(Icons.store_rounded, size: 40, color: Colors.white), SizedBox(height: 8), 
                  Text('أسواق أكسب', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('تسوق بسهولة وأمان',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: navItems.map((item) {
                  return ListTile(
                    leading: Icon(item['icon'] as IconData, color: const Color(0xFF2c3e50)),
                    title: Text(item['title'] as String, style: const TextStyle(fontSize: 16)),
                    trailing: (item['notificationCount'] is int && item['notificationCount'] > 0)
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                            child: Text('${item['notificationCount']}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          )
                        : null,
                    onTap: () {
                      if (item['onTap'] != null) { item['onTap'](); }
                      else { navigateTo(item['route'] as String); }
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              // ✅ أيقونة Material: تسجيل خروج
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text('تسجيل الخروج', style: TextStyle(fontSize: 16, color: Colors.red)),
              onTap: onLogout,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                // ✅ أيقونة Material: رسالة
                Icon(Icons.message_rounded, size: 28, color: Color(0xFF4CAF50)), SizedBox(width: 20),
                // ✅ أيقونة Material: فيسبوك (إذا كانت متوفرة في إصدارك، وإلا استخدم أيقونة عامة)
                Icon(Icons.facebook, size: 28, color: Color(0xFF4CAF50)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // --- بناء الرأس العلوي (Top Header) ---
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 15, bottom: 15, right: 15, left: 15),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF2c3e50), Color(0xFF4CAF50)], begin: Alignment.centerRight, end: Alignment.centerLeft),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: onMenuToggle,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ✅ أيقونة Material: قائمة
                      const Icon(Icons.menu_rounded, size: 28, color: Colors.white),
                      if (menuNotificationDotActive) Positioned(top: -2, right: -2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
                    ],
                  ),
                ),
              ),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ أيقونة Material: متجر
                  Icon(Icons.store_rounded, size: 28, color: Color(0xFF4CAF50)), 
                  SizedBox(width: 8),
                  Text('أسواق أكسب', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              // ✅ أيقونة Material: شمس (شفافة)
              const Icon(Icons.wb_sunny_rounded, size: 28, color: Colors.transparent),
            ],
          ),
          const SizedBox(height: 10),
          Text(userName, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
