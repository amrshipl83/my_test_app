import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/order_model.dart';
import 'dart:developer' as developer;

class OrderDataSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String STATUS_NEW = 'new-order';
  static const String STATUS_PROCESSING = 'processing';
  static const String STATUS_SHIPPED = 'shipped';
  static const String STATUS_DELIVERED = 'delivered';
  static const String STATUS_CANCELLED = 'cancelled';

  /// جلب الطلبات بناءً على الدور مع دمج طلبات المستهلكين للبائع
  Future<List<OrderModel>> loadOrders(String userId, String userRole) async {
    try {
      List<OrderModel> combinedOrders = [];

      if (userRole == 'seller') {
        // 1. جلب طلبات الموردين (المجموعة الأصلية)
        final ordersSnapshot = await _db.collection('orders')
            .where('sellerId', isEqualTo: userId)
            .get();
        
        for (var doc in ordersSnapshot.docs) {
          try {
            combinedOrders.add(OrderModel.fromFirestore(doc));
          } catch (e) {
            developer.log('Error parsing seller order ${doc.id}: $e');
          }
        }

        // 2. جلب طلبات المستهلكين (المجموعة الجديدة) والبحث بـ supermarketId
        final consumerOrdersSnapshot = await _db.collection('consumerorders')
            .where('supermarketId', isEqualTo: userId)
            .get();

        for (var doc in consumerOrdersSnapshot.docs) {
          try {
            // ملاحظة: تأكد من إضافة factory باسم fromConsumerFirestore في موديل OrderModel
            combinedOrders.add(OrderModel.fromConsumerFirestore(doc));
          } catch (e) {
            developer.log('Error parsing consumer order ${doc.id}: $e');
          }
        }

        // ترتيب مجمع لكل الطلبات من الأحدث للأقدم
        combinedOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
        return combinedOrders;
      } 
      
      // للمستهلك أو الأدوار الأخرى (المسار الأصلي)
      else {
        String queryField = (userRole == 'consumer') ? 'customerId' : 'buyer.id';
        String collectionName = (userRole == 'consumer') ? 'consumerorders' : 'orders';

        final querySnapshot = await _db.collection(collectionName)
            .where(queryField, isEqualTo: userId)
            .orderBy('orderDate', descending: true)
            .get();

        return querySnapshot.docs.map((doc) {
          try {
            return (userRole == 'consumer') 
                ? OrderModel.fromConsumerFirestore(doc) 
                : OrderModel.fromFirestore(doc);
          } catch (e) {
            developer.log('Error parsing order ${doc.id}: $e');
            return null;
          }
        }).whereType<OrderModel>().toList();
      }

    } catch (e) {
      developer.log('Order fetching failed: $e', name: 'OrderDataSource', error: e);
      
      // Fallback الأصلي في حالة فشل الـ Index
      final fallbackSnapshot = await _db.collection('orders')
          .where((userRole == 'seller' ? 'sellerId' : 'buyer.id'), isEqualTo: userId)
          .get();
      return fallbackSnapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    }
  }

  /// تحديث حالة الطلب
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      // 🎯 ملاحظة هامة: بما أن البائع أصبح يرى طلبات من مجموعتين،
      // يجب التأكد من تحديث الوثيقة في المجموعة الصحيحة.
      
      // سنحاول التحديث في 'orders' أولاً، وإذا لم نجدها نبحث في 'consumerorders'
      DocumentReference orderDocRef = _db.collection('orders').doc(orderId);
      final doc = await orderDocRef.get();
      
      if (!doc.exists) {
        orderDocRef = _db.collection('consumerorders').doc(orderId);
      }

      final updates = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == STATUS_DELIVERED) {
        updates['deliveryDate'] = FieldValue.serverTimestamp();
      } else if (newStatus == STATUS_CANCELLED) {
        updates['cancellationDate'] = FieldValue.serverTimestamp();
      } else if (newStatus == STATUS_SHIPPED) {
        updates['shippedDate'] = FieldValue.serverTimestamp();
      }

      await orderDocRef.update(updates);
      developer.log('Order $orderId status updated to -> $newStatus', name: 'OrderDataSource');
      
    } catch (e) {
      developer.log('Update Status Error: $e', name: 'OrderDataSource');
      throw Exception('فشل تحديث حالة الطلب.');
    }
  }
}
