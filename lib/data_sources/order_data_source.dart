// lib/data_sources/order_data_source.dart (النسخة المصححة مؤقتاً)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/order_model.dart';
import 'dart:developer' as developer;

class OrderDataSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // دالة مساعدة لتحديد أسماء الحقول بناءً على الدور
  Map<String, String> _getFieldNames(String userRole) {
    if (userRole == 'buyer') {
      return {
        'collection': 'orders',
        'queryField': 'buyer.id',
        'totalField': 'total',
        'unitPriceField': 'price',
      };
    } else if (userRole == 'consumer') {
      return {
        'collection': 'consumerorders',
        'queryField': 'customerId',
        'totalField': 'finalAmount',
        'unitPriceField': 'pricePerUnit',
      };
    } else if (userRole == 'seller') {
      return {
        'collection': 'orders',
        'queryField': 'sellerId',
        'totalField': 'total',
        'unitPriceField': 'price',
      };
    }
    throw Exception('Unsupported user role: $userRole. Must be buyer, consumer, or seller.');
  }

  Future<List<OrderModel>> loadOrders(String userId, String userRole) async {
    try {
      final fields = _getFieldNames(userRole);
      final collectionName = fields['collection']!;
      final queryField = fields['queryField']!;

      developer.log('Fetching orders for $userRole (Collection: $collectionName, Field: $queryField, ID: $userId)', name: 'OrderDataSource');
      final ordersRef = _db.collection(collectionName);

      // ✅ التعديل المؤقت: إزالة .orderBy("orderDate", descending: true)
      final q = ordersRef
          .where(queryField, isEqualTo: userId);

      final querySnapshot = await q.get();

      if (querySnapshot.docs.isEmpty) {
        return [];
      }

      final List<OrderModel> validOrders = [];
      for (var doc in querySnapshot.docs) {
        try {
          final order = OrderModel.fromFirestore(doc);
          validOrders.add(order);
        } catch (e) {
          developer.log('Failed to parse order ID: ${doc.id}. Document skipped.', name: 'OrderDataSource', error: e);
        }
      }
      return validOrders;
    } catch (e) {
      developer.log('Order fetching failed: $e. User Role: $userRole, User ID: $userId', name: 'OrderDataSource', error: e);
      if (e is FirebaseException) {
        throw Exception('Failed to load orders. Firebase Error: ${e.code}. Check Security Rules/Indexes.');
      }
      throw Exception('Failed to load orders. Check your network or data structure.');
    }
  }

  // ⭐️ الدالة الجديدة التي تم إضافتها لتصحيح الخطأ ⭐️
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final orderDocRef = _db.collection('orders').doc(orderId);

      final updates = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // منطق إضافة حقول التاريخ بناءً على الحالة الجديدة (مطابقة لمنطق HTML/JS)
      if (newStatus == 'delivered') {
        updates['deliveryDate'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'cancelled') {
        updates['cancellationDate'] = FieldValue.serverTimestamp();
      }
      
      await orderDocRef.update(updates);
      developer.log('Order $orderId status updated to $newStatus', name: 'OrderDataSource');

    } on FirebaseException catch (e) {
      developer.log('Failed to update order status: ${e.code}', name: 'OrderDataSource', error: e);
      throw Exception('Failed to update order status: ${e.message}');
    } catch (e) {
      developer.log('Unknown error updating order status: $e', name: 'OrderDataSource', error: e);
      throw Exception('Failed to update order status.');
    }
  }
}
