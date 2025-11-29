// المسار: lib/widgets/buyer_category_ads_banner.dart

import 'package:flutter/material.dart';

class BuyerCategoryAdsBanner extends StatelessWidget {
  // ✅ تمت إزالة كلمة const من Constructor هنا
  const BuyerCategoryAdsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 💡 إضافة Padding أفقي لضمان عدم التصاق البانر بأطراف الشاشة
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white, // خلفية بيضاء ليتناسب مع الظل
          // 💡 [تحسين 1]: زيادة الزوايا الدائرية لـ 15
          borderRadius: BorderRadius.circular(15),
          // ❌ إزالة Border.all
          boxShadow: [
            // 💡 [تحسين 2]: تطبيق ظل أنعم وأكثر بروزاً وعمقاً
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              spreadRadius: 0.5,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 💡 [تحسين 1]: تطبيق الزوايا الدائرية على الصورة المقصوصة
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                'https://via.placeholder.com/800x100/4CAF50/FFFFFF?text=إعلان+مميز+في+صفحة+الأقسام',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Text(
                      'مساحة إعلانية',
                      // 💡 استخدام نفس اللون الأخضر الأساسي
                      style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            // أيقونة النجمة (لم يتم تغيير منطقها)
            const Positioned(
              bottom: 5,
              right: 5,
              child: Icon(Icons.star, color: Colors.amber, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
