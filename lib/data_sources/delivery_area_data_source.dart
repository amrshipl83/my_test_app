// lib/data_sources/delivery_area_data_source.dart (النسخة النهائية والمُصحَّحة)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/delivery_area_model.dart';
import 'package:my_test_app/constants/app_constants.dart';
import 'package:flutter/foundation.dart'; // لاستخدام debugPrint

/// مصدر البيانات المسؤول عن التفاعل مع مناطق التوصيل في Firestore.
/// يتم التخزين كقائمة سلاسل نصية (أسماء المناطق) داخل وثيقة البائع في مجموعة 'sellers'.
class DeliveryAreaDataSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// جلب مناطق التوصيل الخاصة بالبائع المعين.
  /// يتم قراءة قائمة أسماء المناطق (List<String>) وتحويلها إلى نماذج DeliveryAreaModel.
  Future<List<DeliveryAreaModel>> fetchAreas(String sellerId) async {
    try {
      // استخدام الثابت SELLERS_COLLECTION المطابق لـ 'sellers' في HTML
      final storeDocRef = _db.collection(SELLERS_COLLECTION).doc(sellerId);
      final storeSnapshot = await storeDocRef.get();

      if (!storeSnapshot.exists) {
        debugPrint('Store document not found for sellerId: $sellerId');
        return [];
      }

      final data = storeSnapshot.data();
      if (data == null || !data.containsKey(DELIVERY_AREAS_FIELD)) {
        return [];
      }

      // 💡 القراءة كقائمة من أسماء المناطق (Strings) كما هو مخزن في HTML
      final areaNames = data[DELIVERY_AREAS_FIELD] as List<dynamic>?;
      if (areaNames == null) {
        return [];
      }

      // تحويل قائمة أسماء المناطق (Strings) إلى نماذج (Models)
      return areaNames
          .whereType<String>() // تصفية للتأكد من أن العناصر سلاسل نصية
          .map((areaName) => DeliveryAreaModel(
                // 🛠️ التصحيح 1: تمرير areaName لكلاً من id و code و name.
                // هذا يضمن أن البيانات الأساسية (التي هي اسم المنطقة) موجودة في الحقول الثلاثة المطلوبة.
                id: areaName,
                code: areaName,
                name: areaName,
                // ownerId و isSelected ستظل null/false
              ))
          .toList();
    } catch (e) {
      debugPrint('Error fetching delivery areas for $sellerId: $e');
      throw Exception('Failed to fetch delivery areas: $e');
    }
  }

  /// تحديث (استبدال) قائمة مناطق التوصيل لوثيقة المتجر.
  /// يتم تحويل قائمة النماذج (DeliveryAreaModel) إلى قائمة أسماء (String) قبل الحفظ.
  Future<void> updateAreas(String sellerId, List<DeliveryAreaModel> areas) async {
    try {
      // استخدام الثابت SELLERS_COLLECTION
      final storeDocRef = _db.collection(SELLERS_COLLECTION).doc(sellerId);

      // 💡 تحويل قائمة النماذج إلى قائمة أسماء المناطق (Strings) كما هو متوقع في HTML
      // نستخدم حقل name للحفظ ليتوافق مع منطق القراءة في HTML
      final areaNamesToSave = areas.map((area) => area.name).toList();

      await storeDocRef.set(
        {DELIVERY_AREAS_FIELD: areaNamesToSave}, // الحفظ كقائمة من Strings
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error updating delivery areas for $sellerId: $e');
      throw Exception('Failed to update delivery areas: $e');
    }
  }
}
