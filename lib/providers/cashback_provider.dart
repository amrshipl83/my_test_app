// lib/providers/cashback_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/buyer_data_provider.dart';

class CashbackProvider with ChangeNotifier {
  final BuyerDataProvider _buyerData;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CashbackProvider(this._buyerData);

  // 1. جلب رصيد الكاش باك (محدث ليتوافق مع الحقول)
  Future<double> fetchCashbackBalance() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) return 0.0;
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return double.tryParse(userDoc.data()?['cashback']?.toString() ?? '0') ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // 2. جلب الأهداف مع حساب التقدم الحقيقي (مطابق لمنطق الويب)
  Future<List<Map<String, dynamic>>> fetchCashbackGoals() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) return [];

    try {
      final now = DateTime.now();
      // جلب القواعد النشطة
      final querySnapshot = await _db.collection("cashbackRules")
          .where("status", isEqualTo: "active")
          .get();

      List<Map<String, dynamic>> goalsList = [];

      for (var docSnap in querySnapshot.docs) {
        final offer = docSnap.data();
        final startDate = (offer['startDate'] as Timestamp).toDate();
        final endDate = (offer['endDate'] as Timestamp).toDate();

        // فحص صلاحية التاريخ (نفس منطق الويب)
        if (now.isBefore(startDate) || now.isAfter(endDate)) continue;

        double minAmount = (offer['minPurchaseAmount'] ?? 0).toDouble();
        String goalBasis = offer['goalBasis'] ?? 'cumulative_spending';

        // --- حساب التقدم من جدول الطلبات ---
        double currentProgressAmount = 0;
        double maxOrderAmount = 0;

        // استعلام الطلبات المسلمة لهذا المستخدم في فترة العرض
        Query ordersQuery = _db.collection("orders")
            .where("buyer.id", isEqualTo: userId)
            .where("status", isEqualTo: "delivered")
            .where("orderDate", isGreaterThanOrEqualTo: startDate)
            .where("orderDate", isLessThanOrEqualTo: endDate);

        // إذا كان العرض لتاجر محدد
        if (offer['appliesTo'] == 'seller' && offer['sellerId'] != null) {
          ordersQuery = ordersQuery.where("seller.id", isEqualTo: offer['sellerId']);
        }

        final ordersSnapshot = await ordersQuery.get();

        for (var orderDoc in ordersSnapshot.docs) {
          final orderData = orderDoc.data() as Map<String, dynamic>;
          double total = (orderData['totalAmount'] ?? orderData['total'] ?? 0).toDouble();
          
          currentProgressAmount += total;
          if (total > maxOrderAmount) maxOrderAmount = total;
        }

        // تحديد القيمة النهائية للتقدم بناءً على نوع الهدف (single_order vs cumulative)
        double finalProgressValue = (goalBasis == 'single_order') ? maxOrderAmount : currentProgressAmount;
        
        double progressPercentage = (finalProgressValue / minAmount) * 100;
        if (progressPercentage > 100) progressPercentage = 100;

        goalsList.add({
          'id': docSnap.id,
          'title': offer['description'] ?? 'هدف كاش باك',
          'minAmount': minAmount,
          'value': offer['value'],
          'type': offer['type'],
          'endDate': endDate,
          'goalBasis': goalBasis,
          'currentProgress': finalProgressValue,
          'progressPercentage': progressPercentage,
          'isAchieved': progressPercentage >= 100,
        });
      }
      return goalsList;
    } catch (e) {
      debugPrint('Error: $e');
      return [];
    }
  }
}
