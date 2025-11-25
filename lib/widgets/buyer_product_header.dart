// المسار: lib/widgets/buyer_product_header.dart

import 'package:flutter/material.dart';

// 💡 يجب استيراد GoogleFonts لضمان استخدام نفس الخطوط الموحدة
import 'package:google_fonts/google_fonts.dart'; 
import 'package:my_test_app/theme/app_theme.dart'; // لتأكيد استخدام اللون الأساسي

class BuyerProductHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isLoading;

  const BuyerProductHeader({
    super.key,
    required this.title,
    this.isLoading = false,
  });

  // دالة وهمية لتحديث السلة (ستُستبدل بـ Provider لاحقاً)
  int _getCartCount() {
    // يمكنك هنا جلب عدد المنتجات من Shared Preferences أو Provider
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    // اللون الأساسي للهيدر (اللون الأخضر الموحد من الثيم)
    final primaryColor = Theme.of(context).primaryColor;

    return AppBar(
      automaticallyImplyLeading: false, // لا نريد زر الرجوع التلقائي
      // 💡 استخدام primaryColor الموحد من الثيم
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 5,
      titleSpacing: 0,

      // الجزء الأيمن: اسم المتجر (Brand Name)
      title: Padding(
        padding: const EdgeInsets.only(right: 15.0),
        child: Row(
          children: [
            const Icon(Icons.store, size: 24),
            const SizedBox(width: 8),
            // 💡 استخدام خط NotoSansArabic الموحد
            Text(
              'أسواق أكسب',
              style: GoogleFonts.notoSansArabic(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),

      // الجزء الأيسر: أيقونات البحث والسلة
      actions: [
        // 1. 🆕 أيقونة البحث (Search Icon) - بدلاً من أيقونة المظهر
        IconButton(
          onPressed: () {
            // 💡 تنفيذ منطق البحث هنا
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم النقر على أيقونة البحث'), duration: Duration(seconds: 1)),
            );
          },
          icon: const Icon(Icons.search, color: Colors.white),
        ),

        // 2. أيقونة السلة (Cart Icon)
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart, size: 22, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pushNamed('/cart'); // يجب تعريف مسار /cart
              },
            ),
            // عرض عدد المنتجات في السلة (Badge)
            if (_getCartCount() > 0)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent, // لون الـ Badge
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '${_getCartCount()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
      ],

      // الجزء السفلي: عنوان القسم الفرعي
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40.0),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
            child: isLoading
                ? const LinearProgressIndicator(backgroundColor: Colors.white54)
                : Text(
                    title,
                    // 💡 استخدام خط NotoSansArabic الموحد
                    style: GoogleFonts.notoSansArabic(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // تحديد الارتفاع المفضل للهيدر (AppBar + Bottom Title)
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 40.0);
}
