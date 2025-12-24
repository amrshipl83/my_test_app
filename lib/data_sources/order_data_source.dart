// lib/data_sources/order_data_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/order_model.dart';
import 'dart:developer' as developer;

class OrderDataSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // تعريف الثوابت لمطابقة ORDER_STATUSES في HTML
  static const String STATUS_NEW = 'new-order';
  static const String STATUS_PROCESSING = 'processing';
  static const String STATUS_SHIPPED = 'shipped';
  static const String STATUS_DELIVERED = 'delivered';
  static const String STATUS_CANCELLED = 'cancelled';

  /// جلب الطلبات بناءً على الدور
  Future<List<OrderModel>> loadOrders(String userId, String userRole) async {
    try {
      String queryField = (userRole == 'seller') ? 'sellerId' : 'buyer.id';
      String collectionName = (userRole == 'consumer') ? 'consumerorders' : 'orders';
      
      if (userRole == 'consumer') queryField = 'customerId';

      developer.log('Fetching orders for $userRole - Collection: $collectionName', name: 'OrderDataSource');

      final querySnapshot = await _db.collection(collectionName)
          .where(queryField, isEqualTo: userId)
          .orderBy('orderDate', descending: true) 
          .get();

      if (querySnapshot.docs.isEmpty) return [];

      return querySnapshot.docs.map((doc) {
        try {
          return OrderModel.fromFirestore(doc);
        } catch (e) {
          developer.log('Error parsing order ${doc.id}: $e', name: 'OrderDataSource');
          return null;
        }
      }).whereType<OrderModel>().toList();

    } catch (e) {
      developer.log('Order fetching failed: $e', name: 'OrderDataSource', error: e);
      
      // Fallback في حالة عدم وجود Index للترتيب
      if (e.toString().contains('failed-precondition') || e.toString().contains('index')) {
        final fallbackSnapshot = await _db.collection('orders')
            .where((userRole == 'seller' ? 'sellerId' : 'buyer.id'), isEqualTo: userId)
            .get();
        return fallbackSnapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      }
      
      throw Exception('تعذر تحميل الطلبات، يرجى التأكد من الاتصال.');
    }
  }

  /// تحديث حالة الطلب - مطابقة تماماً لـ JS في HTML
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final orderDocRef = _db.collection('orders').doc(orderId);

      // 1. الحقول الأساسية المشتركة
      final updates = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(), // مطابق لـ new Date() في JS
      };

      // 2. تحديث تواريخ الحالة بناءً على المنطق المكتوب في HTML (الأسطر 741-744)
      if (newStatus == STATUS_DELIVERED) {
        updates['deliveryDate'] = FieldValue.serverTimestamp();
      } else if (newStatus == STATUS_CANCELLED) {
        updates['cancellationDate'] = FieldValue.serverTimestamp();
      } else if (newStatus == STATUS_SHIPPED) {
        // إضافة shippedDate ليكون التطبيق أشمل من الـ HTML ويخدم نظام التتبع
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

