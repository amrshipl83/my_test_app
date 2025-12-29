// lib/controllers/checkout_controller.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

const Color kPrimaryColor = Color(0xFF4CAF50);
const Color kErrorColor = Color(0xFFE74C3C);
const String CASHBACK_API_ENDPOINT = 'https://l9inzh2wck.execute-api.us-east-1.amazonaws.com/div/cashback';

Map<String, dynamic> removeNullValues(Map<String, dynamic> obj) {
  final Map<String, dynamic> cleanObj = {};
  obj.forEach((key, value) {
    if (value != null) {
      if (value is Map) {
        final cleanedMap = removeNullValues(Map<String, dynamic>.from(value));
        if (cleanedMap.isNotEmpty) cleanObj[key] = cleanedMap;
      } else if (value is List) {
        cleanObj[key] = value.map((e) => e is Map ? removeNullValues(Map<String, dynamic>.from(e)) : e).toList();
      } else {
        cleanObj[key] = value;
      }
    }
  });
  return cleanObj;
}

class CheckoutController {
  static Future<double> fetchCashback(String userId, String userRole) async {
    if (userId.isEmpty) return 0.0;
    final bool isConsumer = (userRole == 'consumer');
    final String collection = isConsumer ? "consumers" : "users";
    final String field = isConsumer ? "cashbackBalance" : "cashback";
    try {
      final doc = await FirebaseFirestore.instance.collection(collection).doc(userId).get();
      return (doc.data()?[field] as num?)?.toDouble() ?? 0.0;
    } catch (e) { return 0.0; }
  }

  static Future<bool> placeOrder({
    required BuildContext context,
    required List<Map<String, dynamic>> checkoutOrders,
    required Map<String, dynamic> loggedUser,
    required double originalOrderTotal,
    required double currentCashback,
    required double finalTotalAmount,
    required bool useCashback,
    required dynamic selectedPaymentMethod,
  }) async {
    if (checkoutOrders.isEmpty || loggedUser['id'] == null) return false;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            SizedBox(width: 20),
            Text("جاري تنفيذ طلبك... يرجى الانتظار", style: TextStyle(fontFamily: 'Tajawal')),
          ],
        ),
        backgroundColor: Color(0xFF2D3142),
        duration: Duration(seconds: 12),
      ),
    );

    final String paymentMethodString = selectedPaymentMethod.toString();
    final Map<String, dynamic> safeLoggedUser = Map<String, dynamic>.from(loggedUser);
    final String? address = safeLoggedUser['address']?.toString();

    if (address == null || address.isEmpty || address == 'null') {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إكمال بيانات العنوان أولاً'), backgroundColor: kErrorColor),
      );
      return false;
    }

    final bool isConsumer = (safeLoggedUser['role'] == 'consumer');
    final String ordersCollection = isConsumer ? "consumerorders" : "orders";
    final List<Map<String, dynamic>> processedOrders = [];

    for (var order in checkoutOrders) {
      Map<String, dynamic> pOrder = Map.from(order);
      final List<Map<String, dynamic>> items = (pOrder['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final List<Map<String, dynamic>> pItems = [];

      for (var item in items) {
        Map<String, dynamic> pItem = Map.from(item);
        final bool isDelFee = (pItem['productId'] == 'DELIVERY_FEE' || (pItem['isDeliveryFee'] ?? false));
        if (!isConsumer && isDelFee) continue; 
        if (((pItem['price'] ?? 0) as num).toDouble() <= 0 && !isDelFee) pItem['isGift'] = true;
        pItems.add(pItem);
      }
      pOrder['items'] = pItems;
      processedOrders.add(pOrder);
    }

    double actualTotal = 0.0;
    for (var o in processedOrders) {
      for (var i in (o['items'] as List)) {
        if (!(i['isGift'] ?? false) && !(i['isDeliveryFee'] ?? false)) {
          actualTotal += (i['price'] as num).toDouble() * (i['quantity'] as num).toDouble();
        }
      }
    }

    final double discountUsed = useCashback ? min(actualTotal, currentCashback) : 0.0;
    final bool isGiftEligible = processedOrders.any((o) => (o['items'] as List).any((i) => i['isGift'] == true));
    final bool needsSecure = !isConsumer && (discountUsed > 0 || isGiftEligible);

    try {
      List<String> successfulIds = [];
      
      if (needsSecure) {
        final payload = {
          'userId': safeLoggedUser['id'],
          'cashbackToReserve': discountUsed,
          'ordersData': processedOrders.map((o) {
             o['buyer'] = {
               'id': safeLoggedUser['id'], 
               'address': address, 
               'name': safeLoggedUser['fullname'],
               'phone': safeLoggedUser['phone'],
               'repCode': safeLoggedUser['repCode'],
               'repName': safeLoggedUser['repName']
             };
             o['paymentMethod'] = paymentMethodString;
             o['status'] = 'new-order';
             return removeNullValues(o);
          }).toList(),
        };

        final response = await http.post(
          Uri.parse(CASHBACK_API_ENDPOINT),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final result = json.decode(response.body);
          if (result['orderIds'] != null) successfulIds.addAll(List<String>.from(result['orderIds']));
        }
      } else {
        for (var o in processedOrders) {
          o['orderDate'] = DateTime.now().toUtc().toIso8601String();
          o['status'] = 'new-order';
          o['paymentMethod'] = paymentMethodString;
          
          if (isConsumer) {
             o['customerId'] = safeLoggedUser['id'];
             o['customerName'] = safeLoggedUser['fullname'];
             o['customerAddress'] = address;
          } else {
             o['buyer'] = {'id': safeLoggedUser['id'], 'address': address, 'name': safeLoggedUser['fullname']};
          }

          final doc = await FirebaseFirestore.instance.collection(ordersCollection).add(removeNullValues(o));
          successfulIds.add(doc.id);
          await doc.update({'orderId': doc.id});
        }
        
        if (discountUsed > 0) {
           final userColl = isConsumer ? "consumers" : "users";
           final field = isConsumer ? "cashbackBalance" : "cashback";
           await FirebaseFirestore.instance.collection(userColl).doc(safeLoggedUser['id']).update({
             field: currentCashback - discountUsed
           });
        }
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (successfulIds.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تنفيذ طلبك بنجاح'), backgroundColor: kPrimaryColor),
        );
        return true;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ حدث خطأ أثناء تنفيذ الطلب'), backgroundColor: kErrorColor),
      );
    }
    return false;
  }
}

