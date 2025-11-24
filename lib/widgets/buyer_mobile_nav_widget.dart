// المسار: lib/widgets/buyer_mobile_nav_widget.dart

import 'package:flutter/material.dart';
// تم حذف استيراد LucideIcons
// import 'package:lucide_icons/lucide_icons.dart';

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

  // 💡 تعريف الصفحات المؤقتة (Pages) لـ BottomNavigationBar                                      
  static final List<Widget> mainPages = const <Widget>[
    PlaceholderScreen(title: 'مشترياتي (orders.html)'), // 0: بديل لـ orders.html                                        
    HomeContent(), // 1: المحتوى الرئيسي (البحث)
    PlaceholderScreen(title: 'السلة (cart.html)'), // 2: بديل لـ cart.html                                            
    PlaceholderScreen(title: 'التجار (traders.html)'), // 3: بديل لـ traders.html
  ];                                            
  
  @override
  Widget build(BuildContext context) {              
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,            
      backgroundColor: Colors.white,                  
      selectedItemColor: const Color(0xFF4CAF50),
      unselectedItemColor: const Color(0xFF555555),                                                   
      currentIndex: selectedIndex,
      onTap: onItemSelected,
      items: [                                          
        // مشترياتي
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              // ✅ أيقونة Material: Icons.shopping_bag_rounded بديل لـ LucideIcons.package
              const Icon(Icons.shopping_bag_rounded),                
              if (ordersChanged) Positioned(top: -4, right: -4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), constraints: const BoxConstraints(minWidth: 8, minHeight: 8))),
            ],
          ),
          label: 'مشترياتى',                            
        ),
        // البحث (الرئيسية)
        // ✅ أيقونة Material: Icons.search_rounded بديل لـ LucideIcons.search
        const BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'البحث'),
        // السلة
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              // ✅ أيقونة Material: Icons.shopping_cart_rounded بديل لـ LucideIcons.shoppingCart
              const Icon(Icons.shopping_cart_rounded),
              if (cartCount > 0) Positioned(top: -8, right: -8, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), constraints: const BoxConstraints(minWidth: 16, minHeight: 16), child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10)))),
            ],
          ),
          label: 'السلة',
        ),                                              
        // التجار
        // ✅ أيقونة Material: Icons.store_rounded بديل لـ LucideIcons.store
        const BottomNavigationBarItem(icon: Icon(Icons.store_rounded), label: 'التجار'),                
      ],
    );                                            
  }
}
