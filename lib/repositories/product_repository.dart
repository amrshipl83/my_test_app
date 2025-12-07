// lib/repositories/product_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ استيراد ProductModel وإخفاء CategoryModel منه لحل التعارض
import 'package:my_test_app/models/product_model.dart' hide CategoryModel; 
// ✅ استيراد CategoryModel من ملفها الصحيح
import 'package:my_test_app/models/category_model.dart'; 
// ✅ استيراد UserRole
import 'package:my_test_app/models/user_role.dart'; 


class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- جلب التصنيفات الرئيسية ---
  Future<List<CategoryModel>> fetchMainCategories() async {
    final snapshot = await _firestore.collection('mainCategory').get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // ✅ التصحيح: استخلاص الحقول المطلوبة (status و order) كما يتم في CategoryModel.fromFirestore
      final statusString = data['status'] as String?; 
      final name = (data['name'] ?? 'قسم غير معروف') as String;
      final imageUrl = (data['imageUrl'] ?? 'https://placehold.co/150x120/43b97f/ffffff?text=Category') as String;
      final order = (data['order'] as num?)?.toInt() ?? 999;
      
      return CategoryModel(
        id: doc.id, 
        name: name,
        imageUrl: imageUrl, 
        // ✅ تمرير القيمة كـ bool بناءً على 'active'
        status: statusString != null && statusString == 'active',
        order: order, 
      );
    }).toList();
  }

  // --- جلب التصنيفات الفرعية ---
  Future<List<CategoryModel>> fetchSubCategories(String? mainCatId) async {
    Query<Map<String, dynamic>> query = _firestore.collection('subCategory');
    if (mainCatId != null && mainCatId.isNotEmpty) {
      query = query.where('mainId', isEqualTo: mainCatId);
    }
    final snapshot = await query.get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      // ✅ التصحيح: استخلاص الحقول المطلوبة (status و order)
      final statusString = data['status'] as String?; 
      final name = (data['name'] ?? 'قسم غير معروف') as String;
      final imageUrl = (data['imageUrl'] ?? 'https://placehold.co/150x120/43b97f/ffffff?text=Category') as String;
      final order = (data['order'] as num?)?.toInt() ?? 999;
      
      return CategoryModel(
        id: doc.id, 
        name: name,
        imageUrl: imageUrl, 
        // ✅ تمرير القيمة كـ bool بناءً على 'active'
        status: statusString != null && statusString == 'active',
        order: order, 
      );
    }).toList();
  }

  // --- دالة البحث الرئيسية ---
  Future<List<ProductModel>> searchProducts({
    required UserRole userRole, 
    required String searchTerm,
    String? mainCategoryId,
    String? subCategoryId,
    required ProductSortOption sortOption, 
  }) async {
    final isConsumer = userRole == UserRole.consumer;
    final productsCollectionName = isConsumer ? 'marketOffer' : 'products';
    final nameField = isConsumer ? 'productName' : 'name';
    final categoryField = isConsumer ? 'mainCategoryId' : 'mainId';
    final subCategoryField = isConsumer ? 'subCategoryId' : 'subId';
    final priceField = isConsumer ? 'price' : 'minPrice';

    // 1. بناء عوامل التصفية (Filters)
    List<WhereComponent> filters = [];

    // فلتر الإتاحة للمستهلك
    if (isConsumer) {
      filters.add(WhereComponent('isAvailable', isEqualTo: true));
    }

    // تحديد ما إذا كان فلتر الأقسام نشطاً
    final bool isCategoryFilterActive = subCategoryId != null && subCategoryId.isNotEmpty ||
                                        mainCategoryId != null && mainCategoryId.isNotEmpty;

    // تطبيق فلاتر الأقسام (تُطبق دائماً إذا كانت موجودة)
    if (subCategoryId != null && subCategoryId.isNotEmpty) {
      filters.add(WhereComponent(subCategoryField, isEqualTo: subCategoryId));
    } else if (mainCategoryId != null && mainCategoryId.isNotEmpty) {
      filters.add(WhereComponent(categoryField, isEqualTo: mainCategoryId));
    }

    // فلتر البحث النصي (Prefix Search)
    if (searchTerm.isNotEmpty && !isCategoryFilterActive) {
      filters.add(WhereComponent(nameField, isGreaterThanOrEqualTo: searchTerm, isLessThanOrEqualTo: '$searchTerm\uf8ff'));
    } else if (searchTerm.isNotEmpty && isCategoryFilterActive) {
      filters.add(WhereComponent(nameField, isGreaterThanOrEqualTo: searchTerm, isLessThanOrEqualTo: '$searchTerm\uf8ff'));
    }

    // 2. بناء عوامل الفرز (Ordering)
    String orderByField = nameField;
    bool descending = false;

    switch (sortOption) {
      case ProductSortOption.nameAsc:
        orderByField = nameField;
        descending = false;
        break;
      case ProductSortOption.nameDesc:
        orderByField = nameField;
        descending = true;
        break;
      case ProductSortOption.priceAsc:
        orderByField = isConsumer ? nameField : priceField;
        descending = false;
        break;
      case ProductSortOption.priceDesc:
        orderByField = isConsumer ? nameField : priceField;
        descending = true;
        break;
    }

    // 3. بناء الاستعلام النهائي
    Query<Map<String, dynamic>> firestoreQuery = _firestore.collection(productsCollectionName);

    // تطبيق الفلاتر
    for (var filter in filters) {
      if (filter.isEqualTo != null) {
        firestoreQuery = firestoreQuery.where(filter.field, isEqualTo: filter.isEqualTo);
      } else if (filter.isGreaterThanOrEqualTo != null && filter.isLessThanOrEqualTo != null) {
        firestoreQuery = firestoreQuery.where(filter.field,
          isGreaterThanOrEqualTo: filter.isGreaterThanOrEqualTo,
          isLessThanOrEqualTo: filter.isLessThanOrEqualTo
        );
      }
    }

    // تطبيق الفرز
    final bool isPrefixSearchActive = searchTerm.isNotEmpty && !isCategoryFilterActive;

    if (isPrefixSearchActive) {
      if (orderByField != nameField) {
        firestoreQuery = firestoreQuery.orderBy(nameField, descending: false)
          .orderBy(orderByField, descending: descending);
      } else {
        firestoreQuery = firestoreQuery.orderBy(nameField, descending: descending);
      }
    } else {
      firestoreQuery = firestoreQuery.orderBy(orderByField, descending: descending);
    }

    final snapshot = await firestoreQuery.get();

    // 4. تحويل النتائج
    return snapshot.docs.map((doc) {
      final data = doc.data();
      double? price;
      String name = (data[nameField] ?? 'غير معروف') as String;

      String imageUrl = isConsumer
          ? (data['productImageUrls'] is List && (data['productImageUrls'] as List).isNotEmpty
              ? (data['productImageUrls'] as List).first
              : 'https://via.placeholder.com/120x120/E0E0E0/757575?text=منتج')
          : (data['imageUrls'] is List && (data['imageUrls'] as List).isNotEmpty
              ? (data['imageUrls'] as List).first
              : 'https://via.placeholder.com/120x120/E0E0E0/757575?text=منتج');

      if (isConsumer) {
        final units = data['units'] as List<dynamic>?;
        price = (units != null && units.isNotEmpty
            ? (units.first as Map<String, dynamic>)['price']
            : data['price'])?.toDouble();
      } else {
        price = data['minPrice']?.toDouble();
      }

      return ProductModel(
        id: doc.id,
        name: name,
        mainCategoryId: data[categoryField] as String?,
        subCategoryId: data[subCategoryField] as String?,
        imageUrl: imageUrl,
        displayPrice: price,
        isAvailable: isConsumer ? (data['isAvailable'] ?? false) : true,
      );
    }).toList();
  }
}

class WhereComponent {
  final String field;
  final dynamic isEqualTo;
  final dynamic isGreaterThanOrEqualTo;
  final dynamic isLessThanOrEqualTo;

  WhereComponent(this.field, {this.isEqualTo, this.isGreaterThanOrEqualTo, this.isLessThanOrEqualTo});
}
