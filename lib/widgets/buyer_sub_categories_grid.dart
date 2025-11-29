// المسار: lib/widgets/buyer_sub_categories_grid.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// 💡 استيراد Google Fonts
import 'package:google_fonts/google_fonts.dart';

class BuyerSubCategoriesGrid extends StatelessWidget {
  final String mainCategoryId;
  // تم إزالة const من الـ Constructor لأن _db غير ثابت
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ✅ التصحيح: تم إزالة const هنا
  BuyerSubCategoriesGrid({
    super.key,
    required this.mainCategoryId,
  });

  // بناء بطاقة القسم الفرعي (بتصميم دائري)
  Widget _buildSubCategoryCard(BuildContext context, Map<String, dynamic> data, String subCategoryId) {
    final name = data['name'] as String? ?? 'قسم فرعي';
    final imageUrl = data['imageUrl'] as String? ?? '';
    final primaryColor = Theme.of(context).primaryColor; // اللون الأخضر الموحد

    final onTap = () {
      // التوجيه إلى صفحة المنتجات (تم تعريفه في main.dart)
      Navigator.of(context).pushNamed(
        '/products',
        arguments: {'subId': subCategoryId, 'mainId': mainCategoryId}
      );
    };

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min, // للحفاظ على الحجم الأدنى
        children: [
          // 1. الحاوية الدائرية (لإعطاء الظل والشكل الأساسي)
          Container(
            width: 90, // حجم الدائرة
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white, // خلفية بيضاء ثابتة
              shape: BoxShape.circle,
              boxShadow: [
                // 💡 [تحسين 1]: تطبيق ظل ناعم وأكثر انتشاراً
                BoxShadow(
                  color: Colors.black.withOpacity(0.1), // ظل أغمق قليلاً
                  spreadRadius: 0.5,
                  blurRadius: 10,
                  offset: const Offset(0, 3), // ظل سفلي
                ),
              ],
            ),
            // 2. قص الصورة داخل الحاوية الدائرية
            child: ClipOval( // ⬅️ استخدام ClipOval لضمان الشكل الدائري للصورة
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      // معالج الأخطاء في حال فشل تحميل الصورة
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          // 💡 [تحسين 3]: استخدام اللون الأساسي الموحد للأيقونة الاحتياطية
                          child: Icon(Icons.category_rounded, size: 40, color: primaryColor),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: Center(
                        // 💡 [تحسين 3]: استخدام اللون الأساسي الموحد للأيقونة الاحتياطية
                        child: Icon(Icons.category_rounded, size: 40, color: primaryColor),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 8),

          // اسم القسم الفرعي
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              name,
              textAlign: TextAlign.center,
              // 💡 [تحسين 2]: استخدام خط Cairo الموحد
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87, // لون نص داكن واضح
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // بناء استعلام Firestore لجلب الأقسام الفرعية
    final subCategoriesQuery = _db.collection('subCategory')
      .where('mainId', isEqualTo: mainCategoryId)
      .where('status', isEqualTo: 'active')
      .orderBy('order', descending: false);

    return StreamBuilder<QuerySnapshot>(
      stream: subCategoriesQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // 💡 [تحسين]: استخدام CircularProgressIndicator بلون التطبيق الأساسي
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('جاري تحميل الأقسام الفرعية...', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('لا توجد أقسام فرعية متاحة حاليًا.'),
            ),
          );
        }

        final subCategories = snapshot.data!.docs;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subCategories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 15,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) {
            final doc = subCategories[index];
            return _buildSubCategoryCard(context, doc.data() as Map<String, dynamic>, doc.id);
          },
        );
      },
    );
  }
}
