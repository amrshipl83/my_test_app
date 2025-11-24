import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/offer_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;
// ⭐️ تم إضافة استيراد الكلاس SelectItemModel من مكانه الصحيح ⭐️
import 'package:my_test_app/models/select_item_model.dart';


// ❌ تم حذف التعريف المكرر لكلاس SelectItemModel من هنا ❌
// لضمان عدم حدوث خطأ ambiguous_import

class AddOfferDataSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 1. جلب الأقسام الرئيسية
  Future<List<SelectItemModel>> loadMainCategories() async {
    final querySnapshot = await _db.collection("mainCategory").get();
    return querySnapshot.docs.map((doc) => SelectItemModel.fromFirestore(doc)).toList();
  }

  /// 2. جلب الأقسام الفرعية
  Future<List<SelectItemModel>> loadSubCategories(String mainCategoryId) async {
    final q = _db.collection("subCategory").where("mainId", isEqualTo: mainCategoryId);
    final querySnapshot = await q.get();
    return querySnapshot.docs.map((doc) => SelectItemModel.fromFirestore(doc)).toList();
  }

  /// 3. جلب المنتجات (مع العروض الحالية)
  Future<Map<String, dynamic>> loadProducts(String subCategoryId, String sellerId) async {
    // أ. جلب جميع المنتجات في القسم الفرعي
    final productsQuery = _db.collection("products").where("subId", isEqualTo: subCategoryId);
    final productsSnapshot = await productsQuery.get();

    final allProducts = productsSnapshot.docs.map((doc) => SelectItemModel.fromFirestore(doc)).toList();

    // ب. جلب العروض الحالية للبائع
    final offersQuery = _db.collection("productOffers")
        .where("sellerId", isEqualTo: sellerId)
        .where("status", isEqualTo: "active");
    final offersSnapshot = await offersQuery.get();

    // خريطة لتخزين الوحدات المعروضة مسبقًا لكل منتج
    final offeredUnitsByProduct = <String, Set<String>>{};

    for (var doc in offersSnapshot.docs) {
      // 🛠️ التحويل الآمن لاستخدام offerData
      final offerData = doc.data() as Map<String, dynamic>;
      final productId = offerData['productId'] as String?;
      final unitsList = offerData['units'] as List<dynamic>?;

      if (productId != null && unitsList != null && unitsList.isNotEmpty) {
        // نأخذ اسم الوحدة من العنصر الأول في قائمة الوحدات
        final unitName = unitsList[0]['unitName'] as String?;
        if (unitName != null) {
          offeredUnitsByProduct.putIfAbsent(productId, () => {}).add(unitName);
        }
      }
    }

    return {
      'allProducts': allProducts,
      'offeredUnitsByProduct': offeredUnitsByProduct,
    };
  }

  /// 4. جلب مناطق توصيل البائع
  Future<List<String>> loadSellerDeliveryAreas(String sellerId) async {
    try {
      final sellerRef = _db.collection("sellers").doc(sellerId);
      final sellerSnap = await sellerRef.get();

      if (sellerSnap.exists) {
        final sellerData = sellerSnap.data();
        final areas = sellerData?['deliveryAreas'];
        if (areas is List) {
          return areas.map((e) => e.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error loading seller delivery areas: $e");
      return [];
    }
  }

  /// 5. إضافة العرض الجديد
  Future<String> addOffer(ProductOfferModel offer) async {
    final offerData = offer.toJson();
    final docRef = await _db.collection("productOffers").add(offerData);
    return docRef.id;
  }
}
