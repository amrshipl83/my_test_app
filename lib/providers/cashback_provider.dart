// lib/providers/cashback_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/buyer_data_provider.dart'; // لتمرير بيانات المستخدم
import '../models/cashback_goal.dart'; // سنفترض هذا الموديل

class CashbackProvider with ChangeNotifier {
  final BuyerDataProvider _buyerData;
  // ... (سأفترض أن لديك موديل CashbackGoal)

  CashbackProvider(this._buyerData);

  // 1. جلب رصيد الكاش باك
  Future<double> fetchCashbackBalance() async {
    final userId = _buyerData.currentUserId; // ✅ الآن Getter موجود
    if (userId == null) return 0.0;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        // الكود HTML استخدم 'cashback' كحقل
        final cashbackAmount = userData?['cashback'] ?? 0.0;
        return double.tryParse(cashbackAmount.toString()) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error fetching cashback balance: $e');
      return 0.0;
    }
  }

  // 2. جلب أهداف الكاش باك (تم تصحيح الأخطاء هنا)
  Future<List<Map<String, dynamic>>> fetchCashbackGoals() async {
    final userId = _buyerData.currentUserId; // ✅ الآن Getter موجود
    // ✅ الآن Getter موجود
    final userClassification = _buyerData.userClassification; 

    if (userId == null) return [];

    try {
      final cashbackRulesRef = FirebaseFirestore.instance.collection("cashbackRules");
      
      // 🟢 [التصحيح 1]: تصحيح استخدام دالة where في Firestore
      var q = cashbackRulesRef
          .where("status", isEqualTo: "active"); 
      
      // 🟢 [إضافة]: تصفية إضافية بناءً على تصنيف المستخدم (مشتري/تاجر)
      q = q.where("userClassification", isEqualTo: userClassification);
      
      final querySnapshot = await q.get();

      List<Map<String, dynamic>> goalsList = [];     
      for (var docSnap in querySnapshot.docs) {              
        final offer = docSnap.data();
        // ... (بقية منطق التحقق من التاريخ والحساب سيكون هنا)

        goalsList.add({
          'id': docSnap.id,
          'title': offer['description'] ?? 'هدف جديد',
          'minAmount': (offer['minPurchaseAmount'] ?? 0).toDouble(),
          'value': offer['value'],
          'type': offer['type'],
          'endDate': (offer['endDate'] as Timestamp).toDate(),                                                      
          'progressPercentage': 50.0, // 🚨 مؤقت
          'currentProgress': 50.0,    // 🚨 مؤقت               
          'isAchieved': false,        // 🚨 مؤقت
        });                                                
      }                                                    
      return goalsList;

    } catch (e) {                                          
      debugPrint('Error fetching cashback goals: $e');
      return [];                                         
    }
  }
}
