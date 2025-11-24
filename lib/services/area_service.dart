// lib/services/area_service.dart

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../constants/delivery_constants.dart';

class AreaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ----------------------------------------------------------------------
  // 1. تحميل GeoJSON
  // ----------------------------------------------------------------------
  /// يقوم بتحميل ملف GeoJSON من الأصول المحلية (assets)
  Future<Map<String, dynamic>?> loadAdministrativeAreas() async {
    try {
      final String jsonString = await rootBundle.loadString(GEOJSON_FILE_PATH);
      final Map<String, dynamic> geoJson = json.decode(jsonString);
      return geoJson;
    } catch (e) {
      print('Error loading GeoJSON: $e');
      return null;
    }
  }

  // ----------------------------------------------------------------------
  // 2. استدعاء AWS Lambda لمزامنة العروض
  // ----------------------------------------------------------------------
  /// يستدعي AWS Lambda لإخبارها بتحديث العروض المرتبطة بالبائع
  Future<int?> callLambdaToUpdateOffers(String sellerId) async {
    print("-> Calling AWS Lambda for offer sync...");
    try {
      final response = await http.post(
        Uri.parse(API_GATEWAY_ENDPOINT),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'sellerId': sellerId}),
      );

      if (!response.statusCode.toString().startsWith('2')) {
        // إذا كان هناك خطأ في API Gateway
        throw Exception('Lambda API failed with status ${response.statusCode}');
      }
      
      final Map<String, dynamic> successBody = json.decode(response.body);
      
      // إرجاع عدد العروض المحدثة
      return successBody['updatedCount'] as int? ?? 0;
      
    } catch (error) {
      print('❌ Failed to call Lambda: $error');
      // عند فشل الاستدعاء، نمرر القيمة null
      return null; 
    }
  }

  // ----------------------------------------------------------------------
  // 3. حفظ مناطق التوصيل
  // ----------------------------------------------------------------------
  /// يحفظ المناطق المختارة في Firestore و يستدعي AWS Lambda
  Future<Map<String, dynamic>> saveSellerAreas({
    required String sellerId,
    required List<String> selectedAreaNames,
  }) async {
    final docRef = _firestore.collection("sellers").doc(sellerId);
    
    try {
      // الخطوة 1: تحديث المصدر الأساسي (sellers) في Firestore
      await docRef.update({
        FIRESTORE_DELIVERY_AREAS_FIELD: selectedAreaNames,
      });

      // الخطوة 2: المحفز! استدعاء Lambda
      final updatedCount = await callLambdaToUpdateOffers(sellerId);

      if (updatedCount != null) {
        return {'success': true, 'message': 'تم الحفظ بنجاح! تم تحديث $updatedCount عروض مرتبطة.'};
      } else {
        return {'success': false, 'message': 'تم حفظ المناطق، لكن حدث خطأ في مزامنة العروض.'};
      }

    } on FirebaseException catch (e) {
      return {'success': false, 'message': 'فشل حفظ المناطق في Firestore: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'فشل غير متوقع أثناء الحفظ: $e'};
    }
  }
}

