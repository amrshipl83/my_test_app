// المسار: lib/widgets/buyer_bottom_nav_bar.dart

import 'package:flutter/material.dart';

class BuyerBottomNavBar extends StatelessWidget {
  const BuyerBottomNavBar({super.key});

  // 💡 هذه الدالة هي للتنقل بين الشاشات الرئيسية للمشتري
  void _onItemTapped(BuildContext context, int index) {
    // 0: الرئيسية (Home), 1: الطلبات (Orders), 2: الإعدادات (Settings)
    // يمكن استخدام Provider/Bloc/Riverpod لتغيير index في شاشة BuyerHomeScreen
    
    String routeName;
    switch (index) {
      case 0:
        // إذا كنا بالفعل في الرئيسية، لا تفعل شيئًا
        if (ModalRoute.of(context)?.settings.name == '/home') return;
        routeName = '/home'; 
        break;
      case 1:
        routeName = '/orders'; // سنقوم بتعريف هذا المسار لاحقاً
        break;
      case 2:
        routeName = '/settings'; // سنقوم بتعريف هذا المسار لاحقاً
        break;
      default:
        return;
    }
    
    // استخدم popUntil للعودة للشاشة الرئيسية وتجنب التراكم
    // نفترض أن BuyerHomeScreen هي المسار '/' أو '/home'
    Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => route.settings.name == '/home' || route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 💡 افتراضياً، سنضع قيمة مؤقتة لـ currentIndex = 0
    // يجب الحصول على القيمة الفعلية من Provider/State Management
    const int currentIndex = 0; 

    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt_outlined),
          activeIcon: Icon(Icons.list_alt),
          label: 'الطلبات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'الإعدادات',
        ),
      ],
      currentIndex: currentIndex,
      selectedItemColor: Theme.of(context).colorScheme.secondary,
      unselectedItemColor: Colors.grey,
      onTap: (index) => _onItemTapped(context, index),
      backgroundColor: Theme.of(context).cardColor,
      elevation: 10,
      type: BottomNavigationBarType.fixed,
    );
  }
}

