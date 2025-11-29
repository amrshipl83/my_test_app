// lib/widgets/seller/seller_sidebar.dart (النسخة النهائية والمصححة بدون تبديل الدور)

import 'package:flutter/material.dart';
import 'package:my_test_app/screens/dummy_screen.dart';
import 'package:my_test_app/screens/seller/add_offer_screen.dart';
import 'package:my_test_app/screens/seller/offers_screen.dart';
import 'package:my_test_app/screens/orders_screen.dart';
import 'package:my_test_app/screens/reports_screen.dart';
import 'package:my_test_app/screens/seller/create_gift_promo_screen.dart';
import 'package:my_test_app/screens/seller/seller_settings_screen.dart';
import 'package:my_test_app/screens/delivery_area_screen.dart';
import 'package:my_test_app/screens/platform_balance_screen.dart';


// لتمثيل بيانات البائع المخزنة محلياً
class SellerUserData {
  final String? fullname;
  SellerUserData({this.fullname});
}

// ⭐️ عنصر القائمة الواحد ⭐️
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget targetScreen;
  final bool isActive;                          
  final int notificationCount;
  final Function(Widget screen) onNavigate;

  const _SidebarItem({
    super.key,
    required this.icon,
    required this.title,
    required this.targetScreen,                 
    required this.isActive,
    required this.onNavigate,                   
    this.notificationCount = 0,
  });
                                                
  @override
  Widget build(BuildContext context) {
    // ⭐️ الألوان الأساسية كما في CSS ⭐️
    const darkSidebarBg = Color(0xff212529);
    const sidebarTextColor = Color(0xffdee2e6);
    const primaryColor = Color(0xff28a745);

    final bool hasNewOrders = notificationCount > 0 && title == 'الطلبات';
    final Color itemColor = hasNewOrders ? Colors.white : sidebarTextColor;                     
    final Color iconColor = hasNewOrders ? Colors.amber : itemColor;
    final Color bgColor = hasNewOrders ? Colors.red.shade700 : (isActive ? const Color(0xff1e7e34) : Colors.transparent);
    final Color activeTextColor = isActive ? Colors.white : itemColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {                           
            Navigator.of(context).pop(); // إغلاق الـ Drawer قبل التوجيه                        
            onNavigate(targetScreen);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(                         
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 10),
                Expanded(                       
                  child: Text(
                    title,
                    style: TextStyle(
                      color: activeTextColor,
                      fontSize: 14,
                      fontWeight: hasNewOrders ? FontWeight.bold : FontWeight.w400,
                    ),
                  ),                            
                ),
                if (notificationCount > 0)      
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: hasNewOrders ? Colors.white : Colors.red.shade700,                 
                      borderRadius: BorderRadius.circular(10),                                  
                    ),
                    child: Text(
                      notificationCount.toString(),
                      style: TextStyle(         
                        color: hasNewOrders ? Colors.red.shade700 : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),                                    
        ),
      ),
    );
  }
}

// ⭐️ الكلاس الأساسي للشريط الجانبي ⭐️
class SellerSidebar extends StatefulWidget {
  final SellerUserData userData;
  final int newOrdersCount;
  final String activeRoute;                     
  final Function(String route, Widget screen) onMenuSelected;                                   
  final String sellerId;
  final bool hasWriteAccess;

  // 🟢🟢 المعامل المطلوب الوحيد الآن 🟢🟢
  final Function() onLogout;
  // ❌ تم حذف onSwitchToBuyer

  const SellerSidebar({                         
    super.key,
    required this.userData,                     
    required this.newOrdersCount,
    required this.activeRoute,
    required this.onMenuSelected,
    required this.sellerId,
    // 🟢 إضافة المتطلب الوحيد
    required this.onLogout,
    // ❌ تم حذف required this.onSwitchToBuyer
    this.hasWriteAccess = true,
  });

  @override
  State<SellerSidebar> createState() => _SellerSidebarState();
}

class _SellerSidebarState extends State<SellerSidebar> {
  late final List<Map<String, dynamic>> _menuItems;

  @override                                     
  void initState() {
    super.initState();

    final currentSellerId = widget.sellerId;

    _menuItems = [
      {'title': 'نظرة عامة', 'icon': Icons.dashboard_outlined, 'screen': const SellerDummyScreen(title: 'نظرة عامة'), 'route': 'نظرة عامة'},
      {'title': 'إضافة عرض', 'icon': Icons.add_circle_outline, 'screen': const AddOfferScreen(), 'route': 'إضافة عرض'},
      {'title': 'العروض المتاحة', 'icon': Icons.local_offer_outlined, 'screen': const OffersScreen(), 'route': 'العروض المتاحة'},
                                                
      // الطلبات
      {'title': 'الطلبات',
       'icon': Icons.list_alt,                  
       'screen': OrdersScreen(userId: currentSellerId, userRole: 'seller'),
       'route': 'الطلبات'},

      // التقارير
      {'title': 'التقارير',
       'icon': Icons.bar_chart_outlined,        
       'screen': ReportsScreen(sellerId: currentSellerId),                                      
       'route': 'التقارير'},
                                                
      // الهدايا الترويجية                      
      {'title': 'الهدايا الترويجية',
       'icon': Icons.card_giftcard,             
       'screen': CreateGiftPromoScreen(currentSellerId: currentSellerId),
       'route': 'الهدايا الترويجية'},

      // حسابي (الإعدادات)
      {'title': 'حسابي',
       'icon': Icons.person_outline,
       'screen': SellerSettingsScreen(currentSellerId: currentSellerId),                        
       'route': 'حسابي'},

      // تحديد مناطق التوصيل
      {'title': 'تحديد مناطق التوصيل',
       'icon': Icons.pin_drop_outlined,
       'screen': DeliveryAreaScreen(
         currentSellerId: currentSellerId,
         hasWriteAccess: widget.hasWriteAccess,
       ),
       'route': 'تحديد مناطق التوصيل'},

      // حساب المنصة
      {'title': 'حساب المنصة',
       'icon': Icons.business_outlined,         
       'screen': const PlatformBalanceScreen(),
       'route': 'حساب المنصة'},

      {'title': 'الخصوصية', 'icon': Icons.security_outlined, 'screen': const SellerDummyScreen(title: 'الخصوصية'), 'route': 'الخصوصية'},
    ];
  }
                                                
  // 🟢 دالة الخروج التي تنفذ الـ Callback 🟢
  void _logout() {
    Navigator.of(context).pop(); // إغلاق الـ Drawer
    widget.onLogout(); 
  }

                                                
  @override
  Widget build(BuildContext context) {          
    // ⭐️ الألوان الأساسية كما في CSS ⭐️
    const darkSidebarBg = Color(0xff212529);
    const sidebarTextColor = Color(0xffdee2e6);
    const primaryColor = Color(0xff28a745);

    return Drawer(
      backgroundColor: darkSidebarBg,           
      child: Column(
        children: [
          // 1. الشعار (Logo) - Drawer Header
          DrawerHeader(                         
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            child: Row(                         
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [                 
                Icon(Icons.widgets_outlined, size: 36, color: primaryColor),
                SizedBox(width: 10),
                Text(
                  'أكسب',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
              ],
            ),                                  
          ),

          // 2. قائمة التصفح (Nav)
          Expanded(                             
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: _menuItems.map((item) {
                return _SidebarItem(
                  icon: item['icon'] as IconData,
                  title: item['title'] as String,
                  targetScreen: item['screen'] as Widget,
                  onNavigate: (screen) => widget.onMenuSelected(item['route'] as String, screen),
                  isActive: widget.activeRoute == item['route'],                                
                  notificationCount: item['route'] == 'الطلبات' ? widget.newOrdersCount : 0,
                );                              
              }).toList(),
            ),
          ),

          // ❌ تم حذف زر التبديل لوضع التسوق بالكامل

          // 3. تسجيل الخروج (Logout)
          Container(                            
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(    
              border: Border(top: BorderSide(color: Color(0x1affffff))),                        
            ),
            child: TextButton.icon(             
              onPressed: _logout, // ربط دالة الخروج
              icon: const Icon(Icons.logout, size: 20, color: sidebarTextColor),
              label: const Text(
                'تسجيل الخروج',                 
                style: TextStyle(color: sidebarTextColor, fontSize: 16),                        
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                alignment: Alignment.centerRight,                                               
              ),
            ),                                  
          ),
        ],                                      
      ),
    );
  }
}

