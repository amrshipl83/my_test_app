// المسار: lib/models/manufacturer_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ManufacturerModel {
  final String id;
  final String name;
  final String description;
  final bool isActive;
  // يمكن إضافة حقول أخرى مثل imageUrl, order, إلخ، لاحقاً

  ManufacturerModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
  });

  // 💡 دالة لإنشاء نموذج من DocumentSnapshot (جلب وثيقة واحدة)
  factory ManufacturerModel.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Manufacturer document data is null for ID: ${doc.id}');
    }
    
    // 💡 استخدام البيانات المحفوظة في لوحة التحكم
    return ManufacturerModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      isActive: data['isActive'] ?? true, // افتراضياً نشط
    );
  }

  // 💡 دالة لإنشاء قائمة من QuerySnapshot (جلب قائمة وثائق)
  static List<ManufacturerModel> fromQuerySnapshot(QuerySnapshot query) {
    return query.docs.map((doc) => ManufacturerModel.fromDocumentSnapshot(doc)).toList();
  }
}
