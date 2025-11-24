// lib/data_sources/offer_data_source.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/offer_model.dart'; // تأكد من استيراد النماذج
import 'package:flutter/foundation.dart' show debugPrint; // 🛠️ تم إضافة استيراد debugPrint

class OfferDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. جلب عروض البائع
  Future<List<ProductOfferModel>> loadSellerOffers(String sellerId) async {
    try {
      final offersQuery = await _firestore
          .collection('productOffers')
          .where('sellerId', isEqualTo: sellerId)
          .get();

      final offers = offersQuery.docs.map((doc) {
        // نستخدم ProductOfferModel.fromFirestore لتحويل البيانات
        // 💡 يفترض أن doc.data() يتم تحويله إلى Map<String, dynamic> بشكل صحيح في النموذج
        // إذا كان التحليل يظهر خطأ هنا، يجب إضافة doc.data() as Map<String, dynamic>
        return ProductOfferModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      return offers;
    } catch (e) {
      // 🛠️ تم استبدال print بـ debugPrint
      debugPrint('Error loading seller offers: $e');
      // يمكن رمي خطأ أو إرجاع قائمة فارغة
      throw Exception('Failed to load offers from database.');
    }
  }

  // 2. تحديث العرض (لنافذة التعديل)
  Future<void> updateOffer(String offerId, Map<String, dynamic> updateData) async {
    try {
      await _firestore.collection('productOffers').doc(offerId).update(updateData);
    } catch (e) {
      // 🛠️ تم استبدال print بـ debugPrint
      debugPrint('Error updating offer $offerId: $e');
      throw Exception('Failed to update offer.');
    }
  }

  // 3. حذف العرض
  Future<void> deleteOffer(String offerId) async {
    try {
      await _firestore.collection('productOffers').doc(offerId).delete();
    } catch (e) {
      // 🛠️ تم استبدال print بـ debugPrint
      debugPrint('Error deleting offer $offerId: $e');
      throw Exception('Failed to delete offer.');
    }
  }

  // **💡 ملاحظة:**
  // يجب أن تكون دالة جلب العروض السابقة (في ملف add_offer_data_source)
  // قد جلبت بالفعل productName و productImage وحفظتهما في وثيقة العرض.
  // إذا لم يحدث ذلك، يجب علينا جلب تفاصيل المنتج هنا ودمجها، لكن سنفترض الآن أن البيانات مخزنة في وثيقة العرض.
}
