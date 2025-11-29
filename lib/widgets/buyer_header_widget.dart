// المسار: lib/widgets/buyer_header_widget.dart
import 'package:flutter/material.dart';
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

  // --- بناء المودال المؤقتة --- (لا تغيير)
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

  // --- دالة مساعدة لـ ListTile (تحسين M3) ---
  static Widget _buildDrawerTile(Function(String) navigate, Map<String, dynamic> item, Color color) {
    // 💡 استخدام FontWeight.w600 لاسم العنصر
    final textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color);

    return ListTile(
      leading: Icon(item['icon'] as IconData, color: color),
      title: Text(item['title'] as String, style: textStyle),
      trailing: (item['notificationCount'] is int && item['notificationCount'] > 0)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              // 💡 تصميم M3 للنوتيفيكيشن (حواف مستديرة أكثر وخط سميك)
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
              child: Text(
                '${item['notificationCount']}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      onTap: () {
        if (item['onTap'] != null) {
          item['onTap']();
        } else if (item['route'] != null) {
          navigate(item['route'] as String);
        }
      },
    );
  }

  // --- بناء القائمة الجانبية (Sidebar / Drawer) --- (تحسين M3)
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

    // 💡 الألوان: اللون الرئيسي للروابط في الـ Drawer
    const Color primaryColor = Color(0xFF2c3e50);
    // 💡 لون التمييز لطلبات الدليفري
    const Color highlightColor = Color(0xFFC62828); // أحمر غامق

    final List<Map<String, dynamic>> navItems = [
      {'title': 'التجار', 'icon': Icons.storefront_rounded, 'route': '/traders'},
      {'title': 'محفظتى', 'icon': Icons.account_balance_wallet_rounded, 'route': '/goals'},
      {'title': 'حسابي', 'icon': Icons.account_circle_rounded, 'route': '/myDetails'},
      {'title': 'من نحن', 'icon': Icons.info_outline_rounded, 'route': '/about'},
      {'title': 'الخصوصية والاستخدام', 'icon': Icons.description_rounded, 'route': '/privacy'},
    ];

    final List<Map<String, dynamic>> deliveryItems = [];

    if (deliverySettingsAvailable) {
      deliveryItems.add({'title': 'خدمة الدليفري', 'icon': Icons.local_shipping_rounded, 'route': '/deliverySettings'});
    }
    if (deliveryPricesAvailable) {
      deliveryItems.add({'title': 'إدارة أسعار الدليفري', 'icon': Icons.price_change_rounded, 'route': '/deliveryPrices'});
    }
    if (deliveryIsActive) {
      deliveryItems.add({
        'title': 'طلبات الدليفري',
        'icon': Icons.shopping_bag_rounded,
        'onTap': () => _showNewOrdersModal(context),
        'notificationCount': newOrdersCount,
      });
    }

    return Drawer(
      child: Column(
        children: [
          // 💡 التحسين M3: الـ DrawerHeader مع التدرج اللوني ولكن بتنسيق أفضل
          const DrawerHeader(
            // 💡 تصميم الرأس الحالي قوي بصرياً ومناسب
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2c3e50), Color(0xFF4CAF50)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0), // Padding أنظف
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store_rounded, size: 40, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'أسواق أكسب',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'تسوق بسهولة وأمان',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // --- المجموعة الأولى: المشتري الأساسي ---
                for (var item in navItems.sublist(0, 3)) _buildDrawerTile(navigateTo, item, primaryColor),
                
                // --- فاصل M3 ---
                const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),

                // --- المجموعة الثانية: وظائف الدليفري/التاجر (المنطق محفوظ) ---
                if (deliveryItems.isNotEmpty) ...[
                  for (var item in deliveryItems)
                    _buildDrawerTile(
                      navigateTo,
                      item,
                      // تمييز طلبات الدليفري بلون مختلف للفت الانتباه
                      item['title'] == 'طلبات الدليفري' ? highlightColor : primaryColor,
                    ),
                  // فاصل M3 بعد مجموعة الدليفري
                  const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                ],

                // --- المجموعة الثالثة: المعلومات والمساعدة ---
                for (var item in navItems.sublist(3)) _buildDrawerTile(navigateTo, item, primaryColor),

                // --- تسجيل الخروج ---
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: highlightColor),
                  title: const Text('تسجيل الخروج', style: TextStyle(fontSize: 16, color: highlightColor, fontWeight: FontWeight.w600)),
                  onTap: onLogout,
                ),
              ],
            ),
          ),
          // 💡 الروابط الاجتماعية (تحسين M3 في الـ Padding)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0), // زيادة الـ Padding السفلي
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.message_rounded, size: 28, color: Color(0xFF4CAF50)),
                SizedBox(width: 24), // زيادة المسافة بين الأيقونات
                Icon(Icons.facebook, size: 28, color: Color(0xFF4CAF50)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- بناء الرأس العلوي (Top Header) --- (تحسين M3)
  @override
  Widget build(BuildContext context) {
    return Container(
      // 💡 التحسين: زيادة الـ Padding العلوي قليلاً ليتناسب مع شريط الحالة
      padding: const EdgeInsets.only(top: 35, bottom: 15, right: 15, left: 15),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2c3e50), Color(0xFF4CAF50)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        // 💡 إضافة ظل خفيف للرأس ليبرز عن محتوى الصفحة
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. زر القائمة (Menu Toggle)
              InkWell(
                onTap: onMenuToggle,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.menu_rounded, size: 30, color: Colors.white), // أيقونة أكبر قليلاً
                      if (menuNotificationDotActive)
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          ), // نقطة أكبر وأكثر وضوحاً
                        ),
                    ],
                  ),
                ),
              ),
              // 2. اسم التطبيق
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store_rounded, size: 28, color: Colors.white), // تغيير لون الأيقونة إلى أبيض
                  SizedBox(width: 8),
                  Text('أسواق أكسب', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              // 3. مساحة احتياطية لموازنة زر القائمة
              const SizedBox(width: 46),
            ],
          ),
          const SizedBox(height: 10),
          // 4. رسالة الترحيب
          Text(
            userName,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
