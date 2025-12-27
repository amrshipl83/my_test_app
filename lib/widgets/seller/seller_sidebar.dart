// lib/widgets/seller/seller_sidebar.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/services/user_session.dart';
import 'package:my_test_app/screens/seller/seller_overview_screen.dart';
import 'package:my_test_app/screens/seller/add_offer_screen.dart';
import 'package:my_test_app/screens/seller/offers_screen.dart';
import 'package:my_test_app/screens/orders_screen.dart';
import 'package:my_test_app/screens/reports_screen.dart';
import 'package:my_test_app/screens/seller/create_gift_promo_screen.dart';
import 'package:my_test_app/screens/seller/seller_settings_screen.dart';
import 'package:my_test_app/screens/delivery_area_screen.dart';
import 'package:my_test_app/screens/platform_balance_screen.dart';

class SellerUserData {
  final String? fullname;
  final bool isSubUser; // أضفناها للتوافق مع التعديلات السابقة
  SellerUserData({this.fullname, this.isSubUser = false});
}

class SellerSidebar extends StatefulWidget {
  final SellerUserData userData;
  final int newOrdersCount;
  final String activeRoute;
  final Function(String route, Widget screen) onMenuSelected;
  final String sellerId;
  final Function() onLogout;

  const SellerSidebar({
    super.key,
    required this.userData,
    required this.newOrdersCount,
    required this.activeRoute,
    required this.onMenuSelected,
    required this.sellerId,
    required this.onLogout,
  });

  @override
  State<SellerSidebar> createState() => _SellerSidebarState();
}

class _SellerSidebarState extends State<SellerSidebar> {
  late List<Map<String, dynamic>> _menuItems;

  @override
  void initState() {
    super.initState();
    _initializeMenu();
  }

  @override
  void didUpdateWidget(covariant SellerSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeMenu();
  }

  void _initializeMenu() {
    final currentSellerId = widget.sellerId;
    final bool canEdit = UserSession.canEdit;
    final bool isOwner = !widget.userData.isSubUser;

    List<Map<String, dynamic>> items = [];

    items.add({
      'title': 'نظرة عامة',
      'icon': Icons.dashboard_rounded,
      'screen': const SellerOverviewScreen(),
      'route': 'نظرة عامة'
    });

    if (canEdit) {
      items.add({
        'title': 'إضافة عرض',
        'icon': Icons.add_box_rounded,
        'screen': const AddOfferScreen(),
        'route': 'إضافة عرض'
      });
    }

    items.addAll([
      {'title': 'العروض المتاحة', 'icon': Icons.local_offer_rounded, 'screen': const OffersScreen(), 'route': 'العروض المتاحة'},
      {'title': 'الطلبات', 'icon': Icons.assignment_rounded, 'screen': OrdersScreen(sellerId: currentSellerId), 'route': 'الطلبات'},
      {'title': 'التقارير', 'icon': Icons.pie_chart_rounded, 'screen': ReportsScreen(sellerId: currentSellerId), 'route': 'التقارير'},
    ]);

    if (canEdit) {
      items.addAll([
        {'title': 'الهدايا الترويجية', 'icon': Icons.card_giftcard_rounded, 'screen': CreateGiftPromoScreen(currentSellerId: currentSellerId), 'route': 'الهدايا الترويجية'},
        {'title': 'تحديد مناطق التوصيل', 'icon': Icons.map_rounded, 'screen': DeliveryAreaScreen(currentSellerId: currentSellerId, hasWriteAccess: true), 'route': 'تحديد مناطق التوصيل'},
      ]);
    }

    items.add({'title': 'حساب المنصة', 'icon': Icons.account_balance_rounded, 'screen': const PlatformBalanceScreen(), 'route': 'حساب المنصة'});

    if (isOwner) {
      items.add({'title': 'حسابي', 'icon': Icons.manage_accounts_rounded, 'screen': SellerSettingsScreen(currentSellerId: currentSellerId), 'route': 'حسابي'});
    }

    _menuItems = items;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xff1a1d21),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xff212529)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: const Color(0xff28a745),
              child: Text(widget.userData.fullname?.substring(0, 1).toUpperCase() ?? "S", style: TextStyle(fontSize: 22.sp, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            accountName: Text(widget.userData.fullname ?? "مورد أكساب", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Colors.white)),
            accountEmail: Text(widget.userData.isSubUser ? "حساب موظف" : "لوحة التحكم الإدارية", style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              // 🎯 التصحيح هنا: إضافة .cast<Widget>() لضمان النوع الصحيح
              children: _menuItems.map((item) {
                return _SidebarItem(
                  icon: item['icon'] as IconData,
                  title: item['title'] as String,
                  targetScreen: item['screen'] as Widget,
                  onNavigate: (screen) {
                    Navigator.pop(context);
                    widget.onMenuSelected(item['route'] as String, screen);
                  },
                  isActive: widget.activeRoute == item['route'],
                  notificationCount: item['route'] == 'الطلبات' ? widget.newOrdersCount : 0,
                );
              }).toList().cast<Widget>(),
            ),
          ),
          const Divider(color: Colors.white10),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
              child: TextButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(minimumSize: Size(double.infinity, 6.h), alignment: Alignment.centerRight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🎯 التأكد من وجود الكلاس هنا ليكون متاحاً للـ Build
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget targetScreen;
  final bool isActive;
  final int notificationCount;
  final Function(Widget screen) onNavigate;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.targetScreen,
    required this.isActive,
    required this.onNavigate,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    const sidebarTextColor = Color(0xffdee2e6);
    const primaryColor = Color(0xff28a745);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0.5.h),
      child: Material(
        color: isActive ? primaryColor.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => onNavigate(targetScreen),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 1.8.h),
            decoration: BoxDecoration(
              border: isActive ? const Border(right: BorderSide(color: primaryColor, width: 5)) : null,
            ),
            child: Row(
              children: [
                Icon(icon, size: 24.sp, color: isActive ? primaryColor : sidebarTextColor),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isActive ? Colors.white : sidebarTextColor,
                      fontSize: 14.sp,
                      fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ),
                if (notificationCount > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      notificationCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

