// lib/services/delivery_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class DeliveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// دالة حساب تكلفة الرحلة المرنة بناءً على المسافة ونوع المركبة
  Future<double> calculateTripCost({
    required double distanceInKm, 
    required String vehicleType // أضفنا هذا المعامل ليكون الدينامو بتاع الحسبة
  }) async {
    try {
      // 1. تحديد اسم المستند بناءً على نوع المركبة
      // motorcycle -> motorcycleConfig
      // pickup -> pickupConfig
      // jumbo -> jumboConfig
      String configDocName = "${vehicleType}Config";
      
      // إذا كان النوع "motorcycle" أو غير معروف، نستخدم الافتراضي deliveryConfig أو motorcycleConfig
      if (vehicleType == "motorcycle" || vehicleType == "") {
        configDocName = "deliveryConfig"; // أو سميه motorcycleConfig لتوحيد الأسماء
      }

      // 2. جلب الإعدادات الخاصة بهذه المركبة من Firestore
      var settingsDoc = await _db.collection('appSettings').doc(configDocName).get();

      // قيم أمان افتراضية (Fallback) في حالة عدم وجود المستند
      double baseFare = 10.0; 
      double kmRate = 5.0;   
      double minFare = 15.0;  
      double serviceFee = 0.0; // رسوم المنصة من العميل

      if (settingsDoc.exists && settingsDoc.data() != null) {
        final data = settingsDoc.data()!;
        baseFare = (data['baseFare'] ?? 10.0).toDouble();
        kmRate = (data['kmRate'] ?? 5.0).toDouble();
        minFare = (data['minFare'] ?? 15.0).toDouble();
        serviceFee = (data['serviceFee'] ?? 0.0).toDouble(); // جلب رسوم الخدمة
      }

      // 3. تطبيق المعادلة المرنة
      // (فتحة العداد + المسافة * سعر الكيلو) + رسوم المنصة
      double tripSubtotal = baseFare + (distanceInKm * kmRate);
      
      // التأكد من الحد الأدنى للمشوار قبل إضافة رسوم الخدمة
      if (tripSubtotal < minFare) {
        tripSubtotal = minFare;
      }

      double totalFinal = tripSubtotal + serviceFee;

      return double.parse(totalFinal.toStringAsFixed(2));
    } catch (e) {
      debugPrint("Error in DeliveryService: $e");
      return 15.0; // سعر طوارئ
    }
  }

  /// دالة حساب المسافة بين نقطتين جغرافيتين بالكيلومتر
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    double distanceInMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    return distanceInMeters / 1000;
  }
}
