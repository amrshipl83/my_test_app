import 'package:cloud_firestore/cloud_firestore.dart';

// نموذج يمثل فئة رئيسية (Main Category)
class CategoryModel {
  final String id;
  final String name;
  final String imageUrl;
  final bool status;
  final int order;
  
  CategoryModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.status,
    required this.order,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return CategoryModel(
      id: doc.id,
      name: data?['name'] as String? ?? 'قسم غير معروف',
      imageUrl: data?['imageUrl'] as String? ?? 'https://placehold.co/150x120/43b97f/ffffff?text=Category',
      status: data?['status'] as String? == 'active',
      order: (data?['order'] as num?)?.toInt() ?? 999,
    );
  }
}
