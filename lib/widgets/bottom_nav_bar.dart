// lib/widgets/bottom_nav_bar.dart

import 'package:flutter/material.dart';

// تعريف الألوان الثابتة المستخدمة في CSS
const Color darkSidebarBg = Color(0xFF212529); // var(--dark-sidebar-bg)
const Color sidebarActiveBg = Color(0xFF1e7e34); // var(--sidebar-active-bg)
const Color sidebarTextColor = Color(0xFFdee2e6); // var(--sidebar-text-color)

// هذا الويدجت هو نموذج مصغر وبسيط لشريط التنقل السفلي
class BottomNavBar extends StatelessWidget {
  final int activeIndex;
  // يمكنك إضافة count للطلبات الجديدة هنا لتمريره في المستقبل
  
  const BottomNavBar({super.key, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    // قائمة الإيقونات والروابط (مؤقتة للتطبيق)
    final items = [
      {'icon': Icons.home, 'label': 'الرئيسية', 'route': 'seller.html'},
      {'icon': Icons.local_offer, 'label': 'العروض', 'route': 'offers.html'},
      {'icon': Icons.list_alt, 'label': 'الطلبات', 'route': 'sellerorder.html', 'notification': 0}, // يمكن تحديثها لاحقاً
      {'icon': Icons.bar_chart, 'label': 'التقارير', 'route': 'seller-reports.html'},
      {'icon': Icons.settings, 'label': 'الإعدادات', 'route': 'seller-setting.html'},
    ];

    return BottomNavigationBar(
      currentIndex: activeIndex,
      onTap: (index) {
        // 💡 منطق التوجيه الفعلي يجب أن يُنفذ هنا 💡
        // Navigator.push... (أو استدعاء دالة التوجيه من الشاشة الرئيسية)
        debugPrint('Navigating to: ${items[index]['label']}');
      },
      type: BottomNavigationBarType.fixed, // يجعل الخلفية ثابتة
      backgroundColor: darkSidebarBg,
      selectedItemColor: Colors.white,
      unselectedItemColor: sidebarTextColor,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      items: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isActive = index == activeIndex;

        return BottomNavigationBarItem(
          icon: Icon(
            item['icon'] as IconData,
            color: isActive ? Colors.white : sidebarTextColor,
            size: isActive ? 26 : 24,
          ),
          label: item['label'] as String,
        );
      }).toList(),
    );
  }
}
