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

      // زر العودة (المنطق لم يتغير)
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),

      // العنوان
      title: isLoading
          ? const LinearProgressIndicator(color: Colors.white)
          : Text(
              title,
              // 💡 [تحسين 3]: استخدام خط Cairo الموحد
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700, // استخدام w700 بدلاً من bold لتوحيد الوزن
              ),
            ),
      centerTitle: true,

      // زر البحث (المنطق لم يتغير)
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 24),
          onPressed: () {
            print('Search button pressed');
          },
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  // تحديد الارتفاع المفضل لم يتغير
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
