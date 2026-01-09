import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BuyerCategoryAdsBanner extends StatelessWidget {
  // 🎯 استلام الـ ID لعمل الفلترة (العلامة)
  final String? categoryId;

  const BuyerCategoryAdsBanner({super.key, this.categoryId});

  @override
  Widget build(BuildContext context) {
    // 💡 نستخدم StreamBuilder ليكون البانر حياً (يتحدث فور تغيير الصورة في Firebase)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('retailerBanners') // سيسحب من نفس المجموعة لتوحيد الإدارة
          .where('status', isEqualTo: 'active')
          .where('targetId', isEqualTo: categoryId) // "العلامة" التي تربط البانر بالقسم
          .where('linkType', isEqualTo: 'CATEGORY') // لضمان أنه بانر مخصص للأقسام
          .snapshots(),
      builder: (context, snapshot) {
        // إذا لم توجد بيانات أو حدث خطأ، لا نعرض شيئاً (يختفي البانر تماماً ولا يترك فراغاً)
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // نأخذ أول بانر مخصص لهذا القسم
        var bannerData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        String imageUrl = bannerData['imageUrl'] ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0),
          child: Container(
            height: 120, // زيادة الارتفاع قليلاً ليكون أوضح
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
