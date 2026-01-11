// lib/providers/manufacturers_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/manufacturer_model.dart'; 
import 'package:flutter/foundation.dart';

class ManufacturersProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<ManufacturerModel> _manufacturers = [];
  List<ManufacturerModel> get manufacturers => _manufacturers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 🎯 التعديل: الدالة الآن تستقبل subCategoryId اختيارياً
  Future<void> fetchManufacturers({String? subCategoryId}) async {
    // منع الجلب المتعدد
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. بناء الاستعلام الأساسي من مجموعة 'manufacturers'
      Query query = _db.collection('manufacturers').where('isActive', isEqualTo: true);

      // 2. 🎯 [الفلترة الجديدة]: إذا تم تمرير معرف قسم فرعي، ابحث عنه داخل مصفوفة subCategoryIds
      if (subCategoryId != null && subCategoryId != 'ALL') {
        query = query.where('subCategoryIds', arrayContains: subCategoryId);
      }

      final querySnapshot = await query.get();

      _manufacturers = ManufacturerModel.fromQuerySnapshot(querySnapshot);
      
      // 3. إضافة خيار "عرض الكل" كأول عنصر دائماً
      // 🛠️ تم إضافة imageUrl: '' هنا لحل خطأ الـ Build
      _manufacturers.insert(0, ManufacturerModel(
          id: 'ALL',
          name: 'عرض الكل',
          description: '',
          imageUrl: '', 
          isActive: true,
      ));

    } on FirebaseException catch (e) {
      _errorMessage = 'خطأ في جلب الشركات المصنعة: ${e.message}';
    } catch (e) {
      _errorMessage = 'خطأ غير متوقع: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
