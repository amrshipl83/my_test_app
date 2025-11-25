// المسار: lib/providers/manufacturers_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/manufacturer_model.dart'; 
import 'package:flutter/foundation.dart'; // نحتاجها في حال أردنا استخدام Debug Print

class ManufacturersProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 💡 قائمة لتخزين الشركات
  List<ManufacturerModel> _manufacturers = [];
  List<ManufacturerModel> get manufacturers => _manufacturers;

  // 💡 حالة التحميل
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // 💡 رسالة الخطأ
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 💡 دالة جلب الشركات المصنعة من Firestore
  Future<void> fetchManufacturers() async {
    // 💡 منع الجلب المتعدد إذا كنا نقوم بالتحميل بالفعل
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 💡 جلب البيانات من مجموعة 'manufacturers' وتصفية النشط منها
      final querySnapshot = await _db
          .collection('manufacturers')
          .where('isActive', isEqualTo: true) // تصفية النشط
          .get();

      _manufacturers = ManufacturerModel.fromQuerySnapshot(querySnapshot);
      
      // 💡 [التعديل هنا]: إضافة خيار "عرض الكل" كأول عنصر دائماً
      _manufacturers.insert(0, ManufacturerModel(
          id: 'ALL', // ID مميز لتمثيل "عرض الكل"
          name: 'عرض الكل', // النص الذي سيظهر في البانر
          description: '',
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
