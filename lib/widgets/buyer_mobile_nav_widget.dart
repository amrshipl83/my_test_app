// المسار: lib/widgets/buyer_mobile_nav_widget.dart

import 'package:flutter/material.dart';

// استيراد محتوى الصفحة الرئيسية
import 'home_content.dart';
// ويدجت نائب (Placeholder) للصفحات غير المكتملة
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('شاشة $title',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50))),
    );
  }
}

class BuyerMobileNavWidget extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final int cartCount;
  final bool ordersChanged;

  const BuyerMobileNavWidget({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.cartCount = 0,
    this.ordersChanged = false,
  });

  // 💡 الترتيب الأصلي: مشترياتي (0)، الرئيسية (1)، السلة (2)، التجار (3)، محفظتي (4)
  static final List<Widget> mainPages = const <Widget>[
    PlaceholderScreen(title: 'مشترياتي (Index 0)'),       // 0: توجيه خارجي
    HomeContent(),                                        // 1: المحتوى الأساسي (البانرات والأقسام)
    PlaceholderScreen(title: 'السلة (Index 2)'),          // 2: توجيه خارجي
    PlaceholderScreen(title: 'التجار (Index 3)'),         // 3: توجيه خارجي
    PlaceholderScreen(title: 'محفظتي (Index 4)'),         // 4: توجيه خارجي
  ];

  @override
  Widget build(BuildContext context) {
    // ⭐️ استخدام NavigationBar (Material 3) ⭐️
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onItemSelected,
      backgroundColor: Colors.white,

      indicatorColor: const Color(0xFF4CAF50).withOpacity(0.1),

      destinations: [
        // 1. مشترياتي (Index 0)
        NavigationDestination(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_bag_outlined),
              if (ordersChanged)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle
                    ),
                    constraints: const BoxConstraints(minWidth: 8, minHeight: 8)
                  )
                ),
            ],
          ),
          selectedIcon: const Icon(Icons.shopping_bag_rounded),
          label: 'مشترياتي',
        ),

        // 2. 🏠 الرئيسية (Index 1)
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: 'الرئيسية',
        ),

        // 3. السلة (Index 2) - يحتوي على عداد السلة
        NavigationDestination(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart_outlined),
              if (cartCount > 0)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10)
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                    )
                  )
                ),
            ],
          ),
          selectedIcon: const Icon(Icons.shopping_cart_rounded),
          label: 'السلة',
        ),

        // 4. التجار (Index 3)
        NavigationDestination(
          icon: const Icon(Icons.store_outlined),
          selectedIcon: const Icon(Icons.store_rounded),
          label: 'التجار',
        ),

        // 5. محفظتي (Index 4)
        NavigationDestination(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
          label: 'محفظتي',
        ),
      ],
    );
  }
}

