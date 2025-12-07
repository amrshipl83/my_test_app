// المسار: lib/widgets/buyer_product_header.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
// 🚀 استيراد مكتبة Sizer
import 'package:sizer/sizer.dart'; 

class BuyerProductHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isLoading;

  const BuyerProductHeader({
    super.key,
    required this.title,
    this.isLoading = false,
  });

  // 💡 دالة التوجيه إلى شاشة السلة
  void _navigateToCart(BuildContext context) {
    Navigator.of(context).pushNamed('/cart');
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return AppBar(
      // 💡 [توحيد]: تفعيل زر العودة التلقائي
      automaticallyImplyLeading: true, 
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      titleSpacing: 0, 

      // 💡 [توحيد M3]: شكل دائري ناعم للأسفل
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
      ),

      // ❌ تم إلغاء استخدام leading التلقائي وسنستخدمه لتخصيص زر العودة
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),

      // 🚀 [التعديل الرئيسي]: جعل العنوان هو اسم القسم الفرعي فقط
      title: isLoading
        ? SizedBox(
            height: 4,
            child: LinearProgressIndicator(color: Colors.white, backgroundColor: Colors.white38)
          )
        : Text(
            title,
            style: GoogleFonts.cairo(
              // 🚀 استخدام Sizer لتوحيد حجم الخط
              fontSize: 17.sp, 
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
      centerTitle: true, // توسيط العنوان

      // 🚀 [التعديل]: أيقونة السلة فقط في الـ actions
      actions: [
        // ❌ تم حذف أيقونة البحث
        
        // 1. أيقونة السلة (Cart Icon)
        Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            final cartCount = cartProvider.cartTotalItems; 

            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart, size: 24, color: Colors.white),
                  onPressed: () => _navigateToCart(context),
                ),
                // عرض عدد المنتجات في السلة (Badge)
                if (cartCount > 0)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5)
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$cartCount',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 8.sp, 
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 8),
      ],

      // ❌ تم حذف bottom: PreferredSize بالكامل لتبسيط الشريط العلوي
      bottom: null,
    );
  }

  // تحديد الارتفاع المفضل للهيدر (الآن هو فقط kToolbarHeight)
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
