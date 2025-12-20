import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class DeliveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<double> calculateTripCost({
    required double distanceInKm,
    required String vehicleType
  }) async {
    try {
      // 1. توحيد اسم المستند (نستخدم نفس الاسم المرسل + Config)
      // إذا كان motorcycle سيبحث عن motorcycleConfig
      // إذا كان pickup سيبحث عن pickupConfig
      String configDocName = "${vehicleType}Config";

      // إذا كانت القيمة فارغة نضع افتراضي
      if (vehicleType.isEmpty) {
        configDocName = "deliveryConfig"; 
      }

      debugPrint("🚕 Calculating for: $configDocName | Distance: ${distanceInKm.toStringAsFixed(2)} km");

      // 2. جلب الإعدادات
      var settingsDoc = await _db.collection('appSettings').doc(configDocName).get();

      // قيم افتراضية (Fallback) في حالة عدم وجود المستند
      double baseFare = 10.0;
      double kmRate = 5.0;
      double minFare = 15.0;
      double serviceFee = 0.0;

      if (settingsDoc.exists && settingsDoc.data() != null) {
        final data = settingsDoc.data()!;
        baseFare = (data['baseFare'] ?? 10.0).toDouble();
        kmRate = (data['kmRate'] ?? 5.0).toDouble();
        minFare = (data['minFare'] ?? 15.0).toDouble();
        serviceFee = (data['serviceFee'] ?? 0.0).toDouble();
        debugPrint("✅ Data Loaded: Base: $baseFare, Rate: $kmRate");
      } else {
        debugPrint("⚠️ Warning: Document $configDocName NOT FOUND. Using defaults.");
        // إذا لم يجد motorcycleConfig جرب البحث في deliveryConfig كخيار أخير
        if (configDocName == "motorcycleConfig") {
           var backupDoc = await _db.collection('appSettings').doc('deliveryConfig').get();
           if (backupDoc.exists) {
              final data = backupDoc.data()!;
              baseFare = (data['baseFare'] ?? 10.0).toDouble();
              kmRate = (data['kmRate'] ?? 5.0).toDouble();
              minFare = (data['minFare'] ?? 15.0).toDouble();
           }
        }
      }

      // 3. الحسبة
      double tripSubtotal = baseFare + (distanceInKm * kmRate);

      if (tripSubtotal < minFare) {
        tripSubtotal = minFare;
      }

      double totalFinal = tripSubtotal + serviceFee;
      return double.parse(totalFinal.toStringAsFixed(2));
    } catch (e) {
      debugPrint("❌ Error in DeliveryService: $e");
      return 15.0;
    }
  }

  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    double distanceInMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    return distanceInMeters / 1000;
  }
}
