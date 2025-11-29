// المسار: lib/widgets/buyer_product_header.dart

import 'package:flutter/material.dart';
// 💡 يجب استيراد GoogleFonts لضمان استخدام نفس الخطوط الموحدة
import 'package:google_fonts/google_fonts.dart';
import 'package:my_test_app/theme/app_theme.dart'; // لتأكيد استخدام اللون الأساسي
// 🆕 [التعديل 1]: استيراد Provider
import 'package:provider/provider.dart';
// 🆕 [التعديل 2]: استيراد CartProvider
import 'package:my_test_app/providers/cart_provider.dart';

class BuyerProductHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isLoading;

  const BuyerProductHeader({
    super.key,
    required this.title,
    this.isLoading = false,
  });

  // ❌ تم حذف دالة _getCartCount() الوهمية واستبدالها بالـ Consumer

  @override
  Widget build(BuildContext context) {
    // اللون الأساسي للهيدر (اللون الأخضر الموحد من الثيم)
    final primaryColor = Theme.of(context).primaryColor;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      // 💡 [تحسين 1]: إضافة ظل معتدل للـ AppBar
      elevation: 4,
      titleSpacing: 0,

      // 💡 [تحسين 2]: إضافة شكل دائري ناعم للأسفل باستخدام ClipRRect
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(15), // زاوية دائرية يسار أسفل
          bottomRight: Radius.circular(15), // ✅ تم التصحيح
        ),
      ),

      // الجزء الأيمن: اسم المتجر (Brand Name)
      title: Padding(
        padding: const EdgeInsets.only(right: 15.0),
        child: Row(
          children: [
            const Icon(Icons.store, size: 24),
            const SizedBox(width: 8),
            // 💡 [تحسين 3]: استخدام خط Cairo بدلاً من NotoSansArabic لتوحيد المظهر
            Text(
              'أسواق أكسب',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w700, // Bold
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),

      // الجزء الأيسر: أيقونات البحث والسلة
      actions: [
        // 1. 🆕 أيقونة البحث (Search Icon)
        IconButton(
          onPressed: () {
            // 💡 تنفيذ منطق البحث هنا
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم النقر على أيقونة البحث'), duration: Duration(seconds: 1)),
            );
          },
          icon: const Icon(Icons.search, color: Colors.white, size: 24),
        ),

        // 2. أيقونة السلة (Cart Icon) - الآن تستخدم Consumer
        Consumer<CartProvider>( // 🆕 [التعديل 3]: تغليف بأيقونة الـ Consumer
          builder: (context, cartProvider, child) {
            // 🛑 [التصحيح 1]: استخدام cartTotalItems لحساب عدد الأصناف وليس الكميات الإجمالية
            final cartCount = cartProvider.cartTotalItems; // 💡 جلب عدد الأصناف الفريدة
            
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart, size: 24, color: Colors.white), // تكبير الأيقونة قليلاً
                  onPressed: () {
                    // 🛑 [التصحيح 2]: استبدال pushNamed بـ push لضمان عمل الانتقال في بيئة غير معرفة المسارات
                    // إذا لم يكن مسار /cart معرّفاً في MaterialApp، فإن pushNamed سيفشل.
                    // الأفضل استخدام push مؤقتاً لصفحة وهمية أو التأكد من تعريف المسار لاحقاً.
                    // لغرض التشغيل السريع، سأستخدم pushNamed مع رسالة خطأ واضحة إذا فشل.
                    try {
                      Navigator.of(context).pushNamed('/cart');
                    } catch (e) {
                      // في حال لم يتم تعريف مسار /cart بعد في MaterialApp
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('❌ المسار "/cart" غير معرف حالياً، يرجى تعريفه.'), backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
                // عرض عدد المنتجات في السلة (Badge)
                if (cartCount > 0) // 💡 استخدام cartCount (عدد الأصناف)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(4), // زيادة الـ Padding للـ Badge
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5) // إضافة إطار أبيض لإبراز الـ Badge
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18, // زيادة الحجم الأدنى
                        minHeight: 18,
                      ),
                      child: Text(
                        '$cartCount', // 💡 استخدام cartCount
                        style: GoogleFonts.cairo( // استخدام خط Cairo أيضاً
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ), // نهاية الـ Consumer
        const SizedBox(width: 10),
      ],

      // الجزء السفلي: عنوان القسم الفرعي
      bottom: PreferredSize(
        // 💡 [تحسين 4]: زيادة الارتفاع المفضل قليلاً
        preferredSize: const Size.fromHeight(45.0),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 20.0, left: 20.0, bottom: 10.0), // زيادة الـ Padding الأفقي والسفلي
            child: isLoading
                ? const LinearProgressIndicator(backgroundColor: Colors.white54)
                : Text(
                    title,
                    // 💡 [تحسين 3]: استخدام خط Cairo
                    style: GoogleFonts.cairo(
                      fontSize: 20, // تكبير حجم الخط قليلاً
                      fontWeight: FontWeight.w700, // Bold
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
  // 💡 [تحسين 4]: تعديل الارتفاع الكلي
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 45.0);
}
