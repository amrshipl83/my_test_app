// lib/services/marketplace_data_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/banner_model.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/models/product_model.dart';
import 'package:my_test_app/models/offer_model.dart';

class MarketplaceDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. جلب البانرات لمتجر معين
  Future<List<BannerModel>> fetchBanners(String ownerId) async {
    try {
      final bannersQuery = await _db.collection('consumerBanners')
          .where('status', isEqualTo: 'active')
          .where('ownerId', isEqualTo: ownerId)
          .orderBy('order', descending: false)
          .get();

      return bannersQuery.docs.map((doc) {
        final data = doc.data();
        return BannerModel(
          id: doc.id,
          imageUrl: data['imageUrl'] ?? '',
          url: data['url'],
          altText: data['altText'],
          order: (data['order'] as num?)?.toInt() ?? 0,
          status: 'active',
        );
      }).toList();
    } catch (e) {
      throw Exception('فشل جلب البانرات: $e');
    }
  }

  // 2. جلب الأقسام بناءً على عروض المتجر
  Future<List<CategoryModel>> fetchCategoriesByOffers(String ownerId) async {
    try {
      final offersSnapshot = await _db.collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      if (offersSnapshot.docs.isEmpty) return [];

      final productIds = offersSnapshot.docs
          .map((doc) => doc.data()['productId'] as String?)
          .where((id) => id != null)
          .toSet();

      if (productIds.isEmpty) return [];

      final productsFutures = productIds.map((id) => _db.collection('products').doc(id!).get());
      final productsSnapshots = await Future.wait(productsFutures);

      final mainCategoryIds = productsSnapshots
          .where((doc) => doc.exists)
          .map((doc) => doc.data()?['mainId'] as String?)
          .where((id) => id != null)
          .toSet();

      if (mainCategoryIds.isEmpty) return [];

      final categoriesFutures = mainCategoryIds.map((id) => _db.collection('mainCategory').doc(id!).get());
      final categoriesSnapshots = await Future.wait(categoriesFutures);

      final List<CategoryModel> activeCategories = [];

      for (var docSnap in categoriesSnapshots) {
        if (docSnap.exists) {
          final data = docSnap.data();
          final statusString = data?['status']?.toString().toLowerCase();
          final isActive = statusString == 'active';

          if (isActive) {
            activeCategories.add(CategoryModel(
              id: docSnap.id,
              name: data?['name'] ?? 'قسم غير مسمى',
              imageUrl: data?['imageUrl'] ?? '',
              order: (data?['order'] as num?)?.toInt() ?? 0,
              status: isActive,
            ));
          }
        }
      }

      activeCategories.sort((a, b) => a.order.compareTo(b.order));
      return activeCategories;
    } catch (e) {
      throw Exception('فشل جلب الأقسام بناءً على العروض: $e');
    }
  }

  // 3. جلب الأقسام الفرعية (SubCategories) بناءً على عروض المتجر والقسم الرئيسي
  Future<List<CategoryModel>> fetchSubCategoriesByOffers(String mainCategoryId, String ownerId) async {
    try {
      final offersSnapshot = await _db.collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      if (offersSnapshot.docs.isEmpty) return [];

      final productIds = offersSnapshot.docs
          .map((doc) => doc.data()['productId'] as String?)
          .where((id) => id != null)
          .toSet();
      if (productIds.isEmpty) return [];

      final productDocsPromises = productIds.map((id) => _db.collection('products').doc(id!).get());
      final productDocs = await Future.wait(productDocsPromises);

      final subCategoryIds = <String>{};
      for (var productDoc in productDocs) {
        if (productDoc.exists) {
          final productData = productDoc.data();
          if (productData?['mainId'] == mainCategoryId && productData?['subId'] != null) {
            subCategoryIds.add(productData!['subId'] as String);
          }
        }
      }

      if (subCategoryIds.isEmpty) return [];

      final subCategoriesPromises = subCategoryIds.map((id) => _db.collection('subCategory').doc(id).get());
      final subCategoriesDocs = await Future.wait(subCategoriesPromises);

      final List<CategoryModel> activeSubCategories = [];

      for (var docSnap in subCategoriesDocs) {
        if (docSnap.exists) {
          final data = docSnap.data();
          final statusString = data?['status']?.toString().toLowerCase();
          final isActive = statusString == 'active';

          if (isActive) {
            activeSubCategories.add(CategoryModel(
              id: docSnap.id,
              name: data?['name'] ?? 'قسم فرعي غير مسمى',
              imageUrl: data?['imageUrl'] ?? '',
              order: (data?['order'] as num?)?.toInt() ?? 0,
              status: isActive,
            ));
          }
        }
      }

      activeSubCategories.sort((a, b) => a.order.compareTo(b.order));
      return activeSubCategories;
    } catch (e) {
      throw Exception('فشل جلب الأقسام الفرعية بناءً على العروض: $e');
    }
  }

  // 4. جلب المنتجات والعروض حسب القسم الفرعي والمتجر
  Future<List<Map<String, dynamic>>> fetchProductsAndOffersBySubCategory({
    required String ownerId,
    required String mainId,
    required String subId,
  }) async {
    try {
      final offersSnapshot = await _db.collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      if (offersSnapshot.docs.isEmpty) return [];

      final productIds = offersSnapshot.docs
          .map((doc) => doc.data()['productId'] as String?)
          .where((id) => id != null)
          .toSet();
      if (productIds.isEmpty) return [];

      final productsQuery = await _db.collection('products')
          .where('mainId', isEqualTo: mainId)
          .where('subId', isEqualTo: subId)
          .where(FieldPath.documentId, whereIn: productIds.toList())
          .get();

      final List<Map<String, dynamic>> results = [];
      for (var productDoc in productsQuery.docs) {
        final productId = productDoc.id;
        final productData = productDoc.data();

        final offerDoc = offersSnapshot.docs.firstWhere(
          (doc) => doc.data()['productId'] == productId,
          orElse: () => throw Exception('Offer not found for product $productId'),
        );

        final offerModel = ProductOfferModel.fromFirestore(offerDoc.data(), offerDoc.id);

        final productModel = ProductModel(
          id: productId,
          name: productData['name'] ?? 'منتج غير مسمى',
          mainCategoryId: productData['mainId'],
          subCategoryId: productData['subId'],
          imageUrls: List<String>.from(productData['imageUrls'] ?? []),
          displayPrice: (productData['displayPrice'] as num?)?.toDouble(),
          isAvailable: productData['isAvailable'] ?? true,
        );

        results.add({
          'product': productModel,
          'offer': offerModel,
        });
      }

      return results;
    } catch (e) {
      throw Exception('فشل جلب المنتجات والعروض: $e');
    }
  }

  // 🟢 5. [التعديل الموحد]: جلب اسم البائع/المتجر الموثوق به من المصدر الصحيح (Consumer أو Buyer) 🟢
  Future<String> fetchSupermarketNameById(String ownerId) async {
    // 1. محاولة البحث في مجموعة المُستهلكين (deliverySupermarkets)
    try {
      final docSnap = await _db.collection('deliverySupermarkets').doc(ownerId).get();
      if (docSnap.exists) {
        final data = docSnap.data();
        // 🟢 اسم المتجر للمستهلك
        return data?['supermarketName'] as String? ?? 'بائع (سوبر ماركت)';
      }
    } catch (e) {
      // تجاهل ومتابعة البحث
    }

    // 2. محاولة البحث في مجموعة المُشترين/الموردين (sellers)
    try {
      final docSnap = await _db.collection('sellers').doc(ownerId).get();
      if (docSnap.exists) {
        final data = docSnap.data();
        // 💡 اسم البائع للمشتري/المورد (افتراض أن الحقل هو 'name')
        return data?['name'] as String? ?? 'بائع (مورد)'; 
      }
    } catch (e) {
      // تجاهل ومتابعة البحث
    }

    // 3. فشل العثور على أي مصدر
    throw Exception('فشل جلب اسم البائع للمعرف $ownerId: غير موجود في أي مجموعة موثوقة.');
  }
}

