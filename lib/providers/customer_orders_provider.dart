// lib/providers/customer_orders_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/consumer_order_model.dart';
import '../constants/constants.dart';
import 'buyer_data_provider.dart';

class CustomerOrdersProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BuyerDataProvider _buyerData;

  bool _isLoading = false;
  String? _message;
  bool _isSuccess = true;
  List<ConsumerOrderModel> _orders = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get message => _message;
  bool get isSuccess => _isSuccess;
  List<ConsumerOrderModel> get orders => _orders;

  CustomerOrdersProvider(this._buyerData) {
    // استدعاء الجلب عند التهيئة
    fetchAndDisplayOrdersForBuyer();
  }

  void showNotification(String msg, bool success) {
    _message = msg;
    _isSuccess = success;
    notifyListeners();
  }

  void clearNotification() {
    _message = null;
    notifyListeners();
  }

  void setIsLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ------------------------------------
  // وظيفة جلب البيانات - نسخة مصححة ومرنة
  // ------------------------------------
  Future<void> fetchAndDisplayOrdersForBuyer() async {
    setIsLoading(true);
    clearNotification();

    final buyerId = _buyerData.loggedInUser?.id;

    if (buyerId == null || buyerId.isEmpty) {
      showNotification('يجب أن تكون مسجلاً كتاجر لعرض الطلبات.', false);
      setIsLoading(false);
      return;
    }

    try {
      // جلب البيانات من مجموعة consumerorders حيث supermarketId هو التاجر الحالي
      final querySnapshot = await _firestore
          .collection(CONSUMER_ORDERS_COLLECTION)
          .where("supermarketId", isEqualTo: buyerId)
          .orderBy('orderDate', descending: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _orders = [];
        showNotification('لا توجد طلبات عملاء حاليًا.', true);
      } else {
        // تحويل الوثائق مع معالجة الأخطاء لكل وثيقة على حدة لضمان استمرار التطبيق
        _orders = querySnapshot.docs.map((doc) {
          try {
            return ConsumerOrderModel.fromFirestore(doc);
          } catch (e) {
            debugPrint("🚨 Error parsing order ${doc.id}: $e");
            return null;
          }
        }).whereType<ConsumerOrderModel>().toList();

        showNotification('تم جلب ${_orders.length} طلب بنجاح.', true);
      }
    } catch (e) {
      debugPrint("❌ Error fetching orders: $e");
      showNotification('حدث خطأ أثناء جلب الطلبات. تأكد من وجود الفهارس (Indexes).', false);
    } finally {
      setIsLoading(false);
    }
  }

  // ------------------------------------
  // تحديث حالة الطلب
  // ------------------------------------
  Future<void> updateOrderStatus(String orderDocId, String newStatus) async {
    final orderIndex = _orders.indexWhere((o) => o.id == orderDocId);
    if (orderIndex == -1) return;

    final orderToUpdate = _orders[orderIndex];
    
    // منع التعديل على الطلبات المنتهية
    if (orderToUpdate.status == 'delivered' || orderToUpdate.status == 'cancelled') {
      showNotification('لا يمكن تعديل طلب منتهي.', false);
      return;
    }

    final originalStatus = orderToUpdate.status;
    
    // تحديث واجهة المستخدم فوراً (Optimistic Update)
    _orders[orderIndex] = orderToUpdate.copyWith(status: newStatus);
    notifyListeners();

    try {
      await _firestore
          .collection(CONSUMER_ORDERS_COLLECTION)
          .doc(orderDocId)
          .update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      showNotification('تم تحديث الحالة بنجاح', true);
    } catch (e) {
      // تراجع عن التغيير في حال فشل الاتصال بقاعدة البيانات
      _orders[orderIndex] = orderToUpdate.copyWith(status: originalStatus);
      notifyListeners();
      showNotification('فشل تحديث الحالة في السيرفر', false);
    }
  }
}

// 💡 إضافة امتداد copyWith لتسهيل تحديث الحالة برمجياً
extension ConsumerOrderModelExtension on ConsumerOrderModel {
  ConsumerOrderModel copyWith({String? status}) {
    return ConsumerOrderModel(
      id: id,
      orderId: orderId,
      customerName: customerName,
      customerAddress: customerAddress,
      customerPhone: customerPhone,
      supermarketId: supermarketId,
      supermarketName: supermarketName,
      supermarketPhone: supermarketPhone,
      finalAmount: finalAmount,
      status: status ?? this.status,
      orderDate: orderDate,
      paymentMethod: paymentMethod,
      deliveryFee: deliveryFee,
      pointsUsed: pointsUsed,
      items: items,
    );
  }
}
