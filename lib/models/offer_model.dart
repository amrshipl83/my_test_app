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
  final String? id; // ID
  final String sellerId;
  final String sellerName;
  final String productId;
  final String productName;
  // 💡 التعديل: أصبح الحقل اختياريًا
  String? imageUrl; // تم إزالة final هنا لكي نتمكن من تعديله بعد الجلب
  final List<String> deliveryZones;
  final List<OfferUnitModel> units;
  final int? minOrder;
  final int? maxOrder;
  final int? lowStockThreshold;
  final String status;
  final Timestamp? createdAt;

  ProductOfferModel({
    this.id,
    required this.sellerId,
    required this.sellerName,
    required this.productId,
    required this.productName,
    this.imageUrl, // 💡 التعديل: لم يعد افتراضياً ''
    this.deliveryZones = const [],
    required this.units,
    this.minOrder,
    this.maxOrder,
    this.lowStockThreshold,
    this.status = "active",
    this.createdAt,
  });

  // 💡 التعديل: لا يتم قراءة imageUrl من data الآن
  factory ProductOfferModel.fromFirestore(Map<String, dynamic> data, String id) {
    final List<dynamic> unitsData = data['units'] ?? [];
    final unitsList = unitsData.map((e) => OfferUnitModel.fromJson(e as Map<String, dynamic>)).toList();

    // 🟢 [التصحيح الرئيسي]: قراءة sellerId/ownerId من البيانات
    final determinedSellerId = data['sellerId'] ?? data['ownerId'] ?? '';
    
    // 🟢 [تعديل إضافي]: قراءة SellerName بناءً على المفاتيح المحتملة
    final determinedSellerName = data['sellerName'] ?? data['ownerName'] ?? 'بائع';


    return ProductOfferModel(
      id: id,
      sellerId: determinedSellerId, // 🟢 تم تعيين قيمة غير فارغة إذا كان ownerId موجوداً
      sellerName: determinedSellerName, // 🟢 تم التعيين
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? 'غير معروف',
      imageUrl: null, // 💡 التعديل: يتم تعيينه إلى null وسيتم تحديثه لاحقاً
      deliveryZones: List<String>.from(data['deliveryZones'] ?? []),
      units: unitsList,
      minOrder: data['minOrder'] as int?,
      maxOrder: data['maxOrder'] as int?,
      lowStockThreshold: data['lowStockThreshold'] as int?,
      status: data['status'] ?? 'inactive',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      // نستخدم sellerId/sellerName هنا لأنهم الحقول الرئيسية للنموذج
      'sellerId': sellerId, 
      'sellerName': sellerName,
      'productId': productId,
      'productName': productName,
      'deliveryZones': deliveryZones,
      'units': units.map((u) => u.toJson()).toList(),
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
    // 💡 التعديل: لا نحفظ imageUrl في Firestore لأنه يتم جلبه من مستند المنتجات

    if (minOrder != null) data['minOrder'] = minOrder;
    if (maxOrder != null) data['maxOrder'] = maxOrder;
    if (lowStockThreshold != null) data['lowStockThreshold'] = lowStockThreshold;

    return data;
  }

  // 💡 دالة للتحديث في مكانها (In-place update)
  void setImageUrl(String url) {
    imageUrl = url;
  }
}
