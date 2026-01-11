// المسار: lib/models/manufacturer_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ManufacturerModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl; // 🎯 تم الإضافة
  final bool isActive;
  final List<String> subCategoryIds; // 🎯 تم الإضافة لدعم الفلترة الذكية

  ManufacturerModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl, // 🎯 تم الإضافة
    required this.isActive,
    this.subCategoryIds = const [], // افتراضياً مصفوفة فارغة
  });

  // 💡 دالة لإنشاء نموذج من DocumentSnapshot
  factory ManufacturerModel.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Manufacturer document data is null for ID: ${doc.id}');
    }
    
    return ManufacturerModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '', // 🎯 قراءة الرابط اللي بيحفظه الآدمن
      isActive: data['isActive'] ?? true,
      // تحويل البيانات القادمة من Firestore إلى قائمة نصوص (List of Strings)
      subCategoryIds: List<String>.from(data['subCategoryIds'] ?? []),
    );
  }

  // 💡 دالة لإنشاء قائمة من QuerySnapshot
  static List<ManufacturerModel> fromQuerySnapshot(QuerySnapshot query) {
    return query.docs.map((doc) => ManufacturerModel.fromDocumentSnapshot(doc)).toList();
  }
}
