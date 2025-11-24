// lib/models/offer_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// نموذج يمثل بيانات الوحدة داخل العرض (units array)
class OfferUnitModel {
  final String unitName;
  final double price;
  final int availableStock;

  OfferUnitModel({
    required this.unitName,
    required this.price,
    required this.availableStock,
  });
  
  // 💡 إضافة دالة التحويل من Firestore
  factory OfferUnitModel.fromJson(Map<String, dynamic> json) {
    return OfferUnitModel(
      unitName: json['unitName'] ?? 'وحدة',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      availableStock: (json['availableStock'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unitName': unitName,
      'price': price,
      'availableStock': availableStock,
    };
  }
}

// نموذج يمثل وثيقة العرض الكاملة (productOffers)
class ProductOfferModel {
  final String? id; // 💡 إضافة ID لسهولة التعديل والحذف
  final String sellerId;
  final String sellerName;
  final String productId;
  final String productName;
  final String imageUrl;
  final List<String> deliveryZones;
  final List<OfferUnitModel> units;
  final int? minOrder;
  final int? maxOrder;
  // 🆕 الحقل الجديد لـ 'حد التحذير'
  final int? lowStockThreshold; 
  final String status;
  final Timestamp? createdAt;

  ProductOfferModel({
    this.id, // ID
    required this.sellerId,
    required this.sellerName,
    required this.productId,
    required this.productName,
    this.imageUrl = '',
    this.deliveryZones = const [],
    required this.units,
    this.minOrder,
    this.maxOrder,
    // 🆕 إضافة الحقل الجديد في الدالة البانية
    this.lowStockThreshold, 
    this.status = "active",
    this.createdAt,
  });

  // 💡 إضافة دالة التحويل من Firestore - ضرورية لشاشة العروض المتاحة
  factory ProductOfferModel.fromFirestore(Map<String, dynamic> data, String id) {
    final List<dynamic> unitsData = data['units'] ?? [];
    final unitsList = unitsData.map((e) => OfferUnitModel.fromJson(e as Map<String, dynamic>)).toList();
    
    return ProductOfferModel(
      id: id,
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? 'بائع',
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? 'غير معروف',
      imageUrl: data['imageUrl'] ?? '',
      deliveryZones: List<String>.from(data['deliveryZones'] ?? []),
      units: unitsList,
      minOrder: data['minOrder'] as int?,
      maxOrder: data['maxOrder'] as int?,
      // 🆕 جلب الحقل الجديد
      lowStockThreshold: data['lowStockThreshold'] as int?, 
      status: data['status'] ?? 'inactive',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }


  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'sellerId': sellerId,
      'sellerName': sellerName,
      'productId': productId,
      'productName': productName,
      'imageUrl': imageUrl,
      'deliveryZones': deliveryZones,
      'units': units.map((u) => u.toJson()).toList(),
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
    
    // يتم إضافة الحقول الاختيارية فقط إذا كانت قيمتها موجودة
    if (minOrder != null) data['minOrder'] = minOrder;
    if (maxOrder != null) data['maxOrder'] = maxOrder;
    // 🆕 إضافة الحقل الجديد لـ toJson
    if (lowStockThreshold != null) data['lowStockThreshold'] = lowStockThreshold; 
    
    return data;
  }
}
