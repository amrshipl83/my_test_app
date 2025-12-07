// المسار: lib/widgets/buyer_category_header.dart

import 'package:flutter/material.dart';
// 💡 استيراد Google Fonts لتوحيد الخطوط
import 'package:google_fonts/google_fonts.dart';

class BuyerCategoryHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isLoading;

  const BuyerCategoryHeader({
    super.key,
    required this.title,
    required this.isLoading,
  });

  // 💡 دالة التوجيه إلى شاشة السلة
  void _navigateToCart(BuildContext context) {
    // المسار المؤكد لشاشة السلة هو '/cart'
    Navigator.of(context).pushNamed('/cart');
  }

  @override
  Widget build(BuildContext context) {
    // 💡 الحصول على اللون الأساسي الموحد من الثيم
    final primaryColor = Theme.of(context).primaryColor;

    return AppBar(
      // 💡 [تحسين 1]: استخدام اللون الأساسي الأخضر الموحد
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,

      // 💡 [تحسين 2]: إضافة شكل دائري ناعم للأسفل
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(15), // زاوية دائرية يسار أسفل
          bottomRight: Radius.circular(15), // زاوية دائرية يمين أسفل
        ),
      ),
      elevation: 4, // ظل معتدل

      // زر العودة (المنطق لم يتغير) - يظهر على اليسار في RTL
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),

      // العنوان (يحتوي الآن على مؤشر التحميل)
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            // 💡 [تحسين 3]: استخدام خط Cairo الموحد
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          // 💡 [تحسين 4]: وضع شريط التقدم الخطي تحت العنوان عند التحميل
          if (isLoading)
            const SizedBox(
              height: 4, // تقليل ارتفاع المؤشر لجعله أرق
              child: LinearProgressIndicator(
                color: Colors.white,
                backgroundColor: Colors.white38,
              ),
            ),
        ],
      ),
      centerTitle: true,

      // 🚀 التعديل: الإبقاء على أيقونة السلة فقط
      actions: [
        IconButton(
          icon: const Icon(Icons.shopping_cart, color: Colors.white, size: 24),
          onPressed: () {
            _navigateToCart(context);
          },
        ),
        
        // ❌ تم حذف زر البحث
        
        const SizedBox(width: 10),
      ],
    );
  }

  // تحديد الارتفاع المفضل لم يتغير
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
