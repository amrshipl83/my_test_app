// المسار: lib/widgets/category_bottom_nav_bar.dart

import 'package:flutter/material.dart';

// 💡 استيراد المسارات الثابتة المطلوبة للتوجيه الخارجي
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/buyer/traders_screen.dart';
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';
import 'package:my_test_app/screens/search/search_screen.dart';


class CategoryBottomNavBar extends StatelessWidget {
  
  const CategoryBottomNavBar({super.key});

  // 💡 الدالة لمعالجة النقر على الشريط السفلي والتوجيه
  void _handleNavigation(BuildContext context, int index) {
    String routeName = '';
    
    // الترتيب: 0: الرئيسية، 1: التجار، 2: مشترياتي، 3: بحث، 4: محفظتي
    
    if (index == 0) {
       // العودة إلى الشاشة الرئيسية كجذر (Root)
       routeName = BuyerHomeScreen.routeName;
       // نستخدم pushNamedAndRemoveUntil لضمان مسح الـ Stack والعودة للشاشة الرئيسية
       Navigator.of(context).pushNamedAndRemoveUntil(routeName, (Route<dynamic> route) => false);
       return;
    } else if (index == 1) { 
      routeName = TradersScreen.routeName;
    } else if (index == 2) { 
      routeName = MyOrdersScreen.routeName;
    } else if (index == 3) { 
      routeName = SearchScreen.routeName;
    } else if (index == 4) {
      routeName = '/wallet'; // مسار المحفظة المُعرّف كـ String
    }
    
    // إذا كان المسار ليس الصفحة الرئيسية، نستخدم pushNamed
    if (routeName.isNotEmpty) {
       Navigator.of(context).pushNamed(routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 💡 استخدام BottomNavigationBar لأنه أبسط وأقل تعقيداً في صفحات التوجيه الفرعية
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed, // لإظهار جميع العناصر
      currentIndex: 0, // دائما نضع الرئيسية (Index 0) هي النشطة افتراضياً في الصفحات الفرعية
      selectedItemColor: const Color(0xFF4CAF50), // اللون الأخضر
      unselectedItemColor: Colors.grey.shade600,
      
      onTap: (index) => _handleNavigation(context, index),
      
      items: const [
        // 0. الرئيسية
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
        // 1. التجار
        BottomNavigationBarItem(icon: Icon(Icons.store_rounded), label: 'التجار'),
        // 2. مشترياتي
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_rounded), label: 'مشترياتي'),
        // 3. بحث
        BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'بحث'),
        // 4. محفظتي
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'محفظتي'),
      ],
    );
  }
}
