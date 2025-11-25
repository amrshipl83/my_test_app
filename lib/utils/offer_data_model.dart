// المسار: lib/utils/offer_data_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String offerId;
  final String sellerId;
  final String sellerName;
  final dynamic price; // يمكن أن يكون int أو double
  final String unitName;
  final int stock;
  final int? minQty;
  final int? maxQty;
  final int? unitIndex; // لتحديد الوحدة داخل مصفوفة الوحدات (إن وجدت)
  final bool disabled;

  OfferModel({
    required this.offerId,
    required this.sellerId,
    required this.sellerName,
    required this.price,
    required this.unitName,
    required this.stock,
    this.minQty = 1, // تم تغيير القيمة الافتراضية
    this.maxQty,
    this.unitIndex = -1,
    this.disabled = false,
  });

  // 💥💥 الدالة الحاسمة المُعدلة لإنشاء قائمة من العروض (وحدات البيع) 💥💥
  // هذه الدالة تعادل منطق الـ JavaScript في بناء offersData
  static List<OfferModel> fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return [];

    final String offerId = doc.id;
    final String sellerId = data['sellerId'] ?? '';
    final String sellerName = data['sellerName'] ?? 'بائع غير معروف';
    final int productMinQty = data['minOrder'] ?? 1;
    final int? productMaxQty = data['maxOrder'];
    
    List<OfferModel> unitsList = [];
    
    // 1. التعامل مع العروض المركبة (مصفوفة الوحدات)
    if (data.containsKey('units') && data['units'] is List) {
      final List units = data['units'] as List;

      units.asMap().forEach((index, unitData) {
        if (unitData is Map<String, dynamic>) {
          final String unitName = unitData['unitName'] ?? 'وحدة غير محددة';
          final dynamic price = unitData['price'] ?? '?';
          final int stock = unitData['availableStock'] ?? 0;
          
          final bool isDisabled = stock < productMinQty;

          unitsList.add(OfferModel(
            offerId: offerId,
            sellerId: sellerId,
            sellerName: sellerName,
            price: price,
            unitName: unitName,
            stock: stock,
            minQty: productMinQty,
            maxQty: productMaxQty,
            unitIndex: index, // مهم جداً لتحديد الوحدة المختارة
            disabled: isDisabled,
          ));
        }
      });
    } 
    
    // 2. التعامل مع العروض البسيطة (وحدة واحدة افتراضية)
    else {
      final dynamic price = data['price'] ?? '?';
      final int stock = data['availableQuantity'] ?? 0;
      final String unitName = data['unitName'] ?? 'وحدة افتراضية';
      
      final bool isDisabled = stock < productMinQty;

      unitsList.add(OfferModel(
        offerId: offerId,
        sellerId: sellerId,
        sellerName: sellerName,
        price: price,
        unitName: unitName,
        stock: stock,
        minQty: productMinQty,
        maxQty: productMaxQty,
        unitIndex: -1, // -1 يشير إلى وحدة افتراضية
        disabled: isDisabled,
      ));
    }
    
    return unitsList;
  }
}

// ⚠️ دالة مساعدة (لتجنب الحاجة إلى حزمة خارجية)
extension IterableExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
