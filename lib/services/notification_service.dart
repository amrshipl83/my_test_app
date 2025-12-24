// lib/services/notification_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static const String _lambdaUrl = 'https://9ayce138ig.execute-api.us-east-1.amazonaws.com/V1/nofiction';

  static Future<void> broadcastPromoNotification({
    required String sellerId,
    required String sellerName,
    required String promoName,
    required List<dynamic> deliveryAreas,
  }) async {
    try {
      debugPrint("🚀 Starting Notification Broadcast Sequence...");

      // 1. جلب المشترين المستهدفين في خطوة واحدة
      Query query = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'buyer');
      if (deliveryAreas.isNotEmpty) {
        query = query.where('city', whereIn: deliveryAreas);
      }
      final buyersSnapshot = await query.get();
      if (buyersSnapshot.docs.isEmpty) return;

      List<String> buyerIds = buyersSnapshot.docs.map((doc) => doc.id).toList();

      // 2. جلب كل الـ ARNs من UserEndpoints دفعة واحدة (Chunks)
      // ملحوظة: لو العدد ضخم جداً (> 500)، يفضل عملها على دفعات، لكن للبداية هذا يكفي
      final endpointsSnapshot = await FirebaseFirestore.instance
          .collection('UserEndpoints')
          .where(FieldPath.documentId, whereIn: buyerIds.take(30).toList()) // Firestore limit is 30 for whereIn
          .get();

      List<String> targetArns = endpointsSnapshot.docs
          .map((doc) => doc.data()['endpointArn'] as String?)
          .where((arn) => arn != null)
          .cast<String>()
          .toList();

      if (targetArns.isEmpty) return;

      // 3. إرسال طلب واحد "Batch" للمدا
      final payload = {
        "action": "BROADCAST_PROMO", // مفتاح للمدا عشان تعرف إن دي دفعة مش واحد بس
        "targetArns": targetArns,
        "title": "عرض هدايا من $sellerName 🎁",
        "message": "وصلك عرض جديد: $promoName. اطلبه الآن من التطبيق!",
      };

      await http.post(
        Uri.parse(_lambdaUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      debugPrint("✅ Batch Notification Request Sent to Lambda");
    } catch (e) {
      debugPrint("🚨 Error in Broadcast: $e");
    }
  }
}

