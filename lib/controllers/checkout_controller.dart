// المسار: lib/controllers/checkout_controller.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// تعريف الألوان (لـ SnackBar)
const Color kPrimaryColor = Color(0xFF4CAF50);
const Color kErrorColor = Color(0xFFE74C3C);

const String CASHBACK_API_ENDPOINT = 'https://l9inzh2wck.execute-api.us-east-1.amazonaws.com/div/cashback';

// ===================================================================
// دالة مساعدة لتنظيف الكائن
// ===================================================================
Map<String, dynamic> removeNullValues(Map<String, dynamic> obj) {
  final Map<String, dynamic> cleanObj = {};
  obj.forEach((key, value) {
    if (value != null) {
      if (value is Map<String, dynamic>) {
        final cleanedMap = removeNullValues(value);
        if (cleanedMap.isNotEmpty) {
          cleanObj[key] = cleanedMap;
        }
      } else if (value is List) {
        final cleanedList = value.map((e) => e is Map<String, dynamic> ? removeNullValues(e) : e).toList();
        cleanObj[key] = cleanedList;
      } else {
        cleanObj[key] = value;
      }
    }
  });
  return cleanObj;
}

// ===================================================================

class CheckoutController {

    // ----------------------------------------------------
    // 🔥🔥 الدالة الجديدة: جلب رصيد الكاش باك من FireStore 🔥🔥
    // ----------------------------------------------------
    static Future<double> fetchCashback(String userId, String userRole) async {
        if (userId.isEmpty) return 0.0;

        final bool isConsumer = (userRole == 'consumer');
        final String usersCollectionName = isConsumer ? "consumers" : "users";
        final String cashbackFieldName = isConsumer ? "cashbackBalance" : "cashback";

        try {
            final userDoc = await FirebaseFirestore.instance.collection(usersCollectionName).doc(userId).get();

            if (userDoc.exists) {
                final fetchedAmount = (userDoc.data()?[cashbackFieldName] as num?)?.toDouble() ?? 0.0;
                return fetchedAmount;
            }
        } catch (e) {
            print('❌ Error fetching cashback for user $userId from $usersCollectionName: $e');
        }
        return 0.0;
    }

    // ----------------------------------------------------
    // 🎯 دالة تنفيذ تأكيد الطلب
    // ----------------------------------------------------
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

        if (checkoutOrders.isEmpty || loggedUser['id'] == null) {
            return false;
        }

        final String paymentMethodString = selectedPaymentMethod.toString();
        final dynamic buyerLocation = loggedUser['location'];
        final String? rawAddress = loggedUser['address']?.toString();
        final String? rawRepCode = loggedUser['repCode']?.toString();
        final String? rawRepName = loggedUser['repName']?.toString();

        final String? address = (rawAddress == null || rawAddress.isEmpty || rawAddress == 'null') ? null : rawAddress;
        final String? repCode = (rawRepCode == null || rawRepCode.isEmpty || rawRepCode == 'null') ? null : rawRepCode;
        final String? repName = (rawRepName == null || rawRepName.isEmpty || rawRepName == 'null') ? null : rawRepName;

        if (address == null || address.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('الرجاء إكمال بيانات العنوان قبل تأكيد الطلب.'), backgroundColor: kErrorColor)
            );
            return false;
        }

        final bool isConsumer = (loggedUser['role'] == 'consumer');
        final String ordersCollectionName = isConsumer ? "consumerorders" : "orders";
        final String usersCollectionName = isConsumer ? "consumers" : "users";
        final String cashbackFieldName = isConsumer ? "cashbackBalance" : "cashback";

        // 🎯🎯 التعديل 1: استخدام checkoutOrders مباشرة كقائمة مُجمَّعة (إلغاء التجميع المزدوج)
        final List<Map<String, dynamic>> groupedOrdersList = checkoutOrders;
        final Map<String, Map<String, dynamic>> groupedItems = {
            for (var order in groupedOrdersList) order['sellerId'] as String: order
        };

        final double discountUsed = useCashback
            ? min(originalOrderTotal, currentCashback)
            : 0.0;

        final bool isGiftEligible = checkoutOrders.any((item) => item['isGift'] == true);

        final bool needsSecureProcessing = !isConsumer && (discountUsed > 0 || isGiftEligible);

        print('--- Order Processing Summary ---');
        print('Needs Secure API Processing: $needsSecureProcessing');
        print('----------------------------------');

        try {
            List<String> successfulOrderIds = [];
            final uniqueSellerIds = groupedItems.keys.toList();

            // جلب نسب العمولات الحقيقية من FireStore (مجموعة sellers)
            final Map<String, double> commissionRatesCache = {};
            if (!isConsumer) {
                for (final sellerId in uniqueSellerIds) {
                    double commissionRate = 0.0;
                    try {
                        final sellerSnap = await FirebaseFirestore.instance.collection("sellers").doc(sellerId).get();
                        if (sellerSnap.exists) {
                            final fetchedCommissionRate = sellerSnap.data()?['commissionRate'] as num?;
                            if (fetchedCommissionRate != null) {
                                commissionRate = fetchedCommissionRate.toDouble();
                            }
                        }
                    } catch (e) {
                        print('❌ Error fetching commission for seller $sellerId: $e');
                    }
                    commissionRatesCache[sellerId] = commissionRate;
                }
            }

            // ===================================================================================
            // 🔥🔥 المسار الآمن: Buyer ويحتاج كاش باك أو هدية (API Gateway)
            // ⚠️ (تم الإبقاء على منطق الحساب القديم هنا مؤقتاً لحين مراجعة Buyer)
            // ===================================================================================
            if (needsSecureProcessing) {
                print('>>> SCENARIO 1: Buyer Order. Processing via SECURE API <<<');

                final List<Map<String, dynamic>> allOrdersData = [];

                for (final sellerId in groupedItems.keys) {
                    final sellerOrder = groupedItems[sellerId]!;

                    // إعادة الحساب لمتطلبات الـ API
                    double deliveryFee = 0.0;
                    final regularItems = sellerOrder['items'].where((item) => item['isDeliveryFee'] != true && item['isGift'] != true).toList();
                    final sellerDeliveryItem = sellerOrder['items'].firstWhere((item) => item['productId'] == 'DELIVERY_FEE', orElse: () => {});

                    if (sellerDeliveryItem.isNotEmpty) {
                        deliveryFee = (sellerDeliveryItem['price'] as num?)?.toDouble() ?? 0.0;
                    }

                    final double subtotalPrice = regularItems.fold(
                            0.0, (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toDouble() ?? 0.0)
                    );
                    final double orderSubtotalWithDelivery = subtotalPrice + deliveryFee;

                    double discountPortion = 0.0;
                    if (originalOrderTotal > 0 && discountUsed > 0) {
                        discountPortion = (orderSubtotalWithDelivery / originalOrderTotal) * discountUsed;
                    }

                    final List<Map<String, dynamic>> payloadItems = [...regularItems];
                    if (sellerDeliveryItem.isNotEmpty) {
                        payloadItems.add(sellerDeliveryItem);
                    }
                    
                    final orderData = {
                        // ... (بناء بيانات الطلب لـ API)
                        'sellerId': sellerId,
                        'items': payloadItems,
                        'total': orderSubtotalWithDelivery, // إجمالي قبل الخصم
                        'paymentMethod': paymentMethodString,
                        'status': 'new-order',
                        'orderDate': DateTime.now().toUtc().toIso8601String(), 

                        'commissionRate': commissionRatesCache[sellerId] ?? 0.0,
                        'cashbackApplied': discountPortion,
                        'isCashbackUsed': discountUsed > 0,
                        'profitCalculationStatus': "PENDING",
                        'cashbackProcessedPerOrder': false,
                        'cashbackProcessedCumulative': false,

                        'buyer': { 
                            'name': loggedUser['fullname'],
                            'phone': loggedUser['phone'],
                            'email': loggedUser['email'],
                            'address': address,
                            'location': buyerLocation,
                            'repCode': repCode,
                            'repName': repName
                        },
                    };
                    allOrdersData.add(removeNullValues(orderData));
                }

                // ... (منطق إرسال API)
                final payload = {
                    'userId': loggedUser['id'],
                    'cashbackToReserve': discountUsed,
                    'ordersData': allOrdersData,
                    'checkoutId': 'CHECKOUT-${loggedUser['id']}-${DateTime.now().millisecondsSinceEpoch}',
                };

                try {
                    print('  - Sending payload to API: $CASHBACK_API_ENDPOINT');

                    final response = await http.post(
                        Uri.parse(CASHBACK_API_ENDPOINT),
                        headers: { 'Content-Type': 'application/json' },
                        body: json.encode(removeNullValues(payload)),
                    );

                    final result = json.decode(response.body);

                    if (response.statusCode >= 200 && response.statusCode < 300) {
                        successfulOrderIds = (result['orderIds'] is List)
                            ? List<String>.from(result['orderIds'])
                            : (result['orderId'] != null ? [result['orderId'].toString()] : []);
                    } else {
                        String errorMessage = (result is Map && result.containsKey('message')) ? result['message'].toString() : 'فشل تأكيد الطلب عبر المسار الآمن.';
                        throw Exception(errorMessage);
                    }
                } catch (e) {
                    String errorDescription = (e is Exception) ? e.toString().replaceFirst("Exception: ", "") : 'خطأ في الشبكة أو الاتصال بالخادم.';
                    print('❌ API Error in secure path: $errorDescription');
                    throw Exception(errorDescription);
                }
            } else {
                // ===================================================================================
                // 💾 المسار المباشر: Direct Firestore Write (مسار المستهلك المصحح)
                // ===================================================================================
                print('>>> SCENARIO 2/3: Processing via DIRECT Firestore Write <<<');

                for (final sellerId in groupedItems.keys) {
                    final sellerOrder = groupedItems[sellerId]!;

                    // 1. استخلاص الأصناف الأصلية
                    final List<Map<String, dynamic>> allPaidItems = (sellerOrder['items'] as List?)?.cast<Map<String, dynamic>>() ?? []; 

                    // 2. 💥💥 إعادة الحساب الدقيق من الأصناف (لضمان تفكيك الإجماليات) 💥💥
                    double calculatedSubtotalPrice = 0.0;
                    double calculatedDeliveryFee = 0.0;
                    
                    for (var item in allPaidItems) {
                        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                        final itemTotal = price * quantity;

                        // نعتمد على productId الموحد (DELIVERY_FEE) لتحديد رسوم التوصيل
                        if (item['productId'] == 'DELIVERY_FEE') { 
                            calculatedDeliveryFee += itemTotal;
                        } else {
                            // جمع أسعار المنتجات المدفوعة فقط
                            if (!(item['isGift'] ?? false)) {
                                calculatedSubtotalPrice += itemTotal;
                            }
                        }
                    }

                    // 3. استخدام القيم المحسوبة للتفكيك
                    final double subtotalPrice = calculatedSubtotalPrice; // ✅ إجمالي المنتجات فقط
                    final double deliveryFee = calculatedDeliveryFee;       // ✅ رسوم التوصيل فقط

                    // 4. حساب الإجمالي النهائي بعد الخصم (نقاط الكاش باك)
                    final double orderSubtotalWithDelivery = subtotalPrice + deliveryFee;
                    double discountPortion = 0.0;
                    if (originalOrderTotal > 0 && discountUsed > 0) {
                        discountPortion = (orderSubtotalWithDelivery / originalOrderTotal) * discountUsed;
                    }
                    final double finalAmountForOrder = orderSubtotalWithDelivery - discountPortion;

                    final String sellerName = sellerOrder['sellerName'] ?? 'بائع غير معروف';
                    final String? sellerPhone = allPaidItems.isNotEmpty ? allPaidItems.firstWhere((item) => item['sellerPhone'] != null, orElse: () => {})['sellerPhone'] as String? : null;

                    Map<String, dynamic> orderData;
                    if (isConsumer) {
                        orderData = {
                            'customerId': loggedUser['id'],
                            'customerName': loggedUser['fullname'],
                            'customerPhone': loggedUser['phone'],
                            'customerEmail': loggedUser['email'],
                            'customerAddress': address,
                            'deliveryLocation': buyerLocation,

                            'supermarketId': sellerId,
                            'supermarketName': sellerName,
                            'supermarketPhone': sellerPhone,

                            'items': allPaidItems,
                            
                            // 💥💥 الحقول المصححة والمفككة 💥💥
                            'deliveryFee': deliveryFee,
                            'subtotalPrice': subtotalPrice,
                            'finalAmount': finalAmountForOrder,

                            // حقول الكاش باك للباك إند
                            'pointsUsed': discountPortion,
                            'pointsEarned': 0,
                            'points_calculated': false,

                            'paymentMethod': paymentMethodString,
                            'status': 'new-order',
                            'orderDate': DateTime.now().toUtc().toIso8601String(),
                        };
                    } else {
                        // ... (كود البائع/Buyer - لم يتم تعديله بعد)
                        orderData = {
                            'buyer': {
                                'id': loggedUser['id'],
                                'name': loggedUser['fullname'],
                                'phone': loggedUser['phone'],
                                'email': loggedUser['email'],
                                'address': address,
                                'location': buyerLocation,
                                'repCode': repCode,
                                'repName': repName
                            },
                            'sellerId': sellerId,
                            'items': allPaidItems,
                            'total': orderSubtotalWithDelivery,
                            'paymentMethod': paymentMethodString,
                            'status': 'new-order',
                            'orderDate': DateTime.now().toUtc().toIso8601String(),

                            'commissionRate': commissionRatesCache[sellerId] ?? 0.0,
                            'isCommissionProcessed': false,
                            'unrealizedCommissionAmount': 0,
                            'isFinancialSettled': false,
                            'orderHandled': false,
                            'cashbackApplied': discountPortion,
                            'isCashbackUsed': discountUsed > 0,
                            'isCashbackReserved': false,

                            'cashbackProcessedPerOrder': false,
                            'cashbackProcessedCumulative': false,
                            'profitCalculationStatus': "PENDING",
                        };
                    }

                    try {
                        final finalOrderData = removeNullValues(orderData);
                        final docRef = await FirebaseFirestore.instance.collection(ordersCollectionName).add(finalOrderData);
                        final String orderId = docRef.id;
                        successfulOrderIds.add(orderId);
                        await FirebaseFirestore.instance.collection(ordersCollectionName).doc(orderId).set({ 'orderId': orderId }, SetOptions(merge: true));

                    } catch (e) {
                        print('  ❌ General Error processing order for seller $sellerId: $e');
                    }
                }

                // خصم الكاش باك الفوري
                if (discountUsed > 0 && successfulOrderIds.isNotEmpty) {
                    try {
                        final newCashbackBalance = currentCashback - discountUsed;
                        await FirebaseFirestore.instance.collection(usersCollectionName).doc(loggedUser['id']).set({
                            cashbackFieldName: newCashbackBalance
                        }, SetOptions(merge: true));
                    } catch (error) {
                        print("❌ Failed to deduct cashback in Firestore (Immediate deduction): $error");
                    }
                }
            }

            // 8. إنهاء العملية
            if (successfulOrderIds.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('✅ تم الطلب بنجاح ونقله للاستور!'),
                        backgroundColor: kPrimaryColor
                    )
                );
                return true;
            } else {
                return false;
            }

        } catch (e) {
            print("Order placement error: $e");
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ خطأ غير متوقع أثناء إتمام الطلب: ${e.toString()}'), backgroundColor: kErrorColor)
            );
            return false;
        }
    }
}
