import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// --- النماذج (Models) ---
class OrderItemModel {
  final String name;
  final int quantity;
  final double price;

  OrderItemModel({required this.name, required this.quantity, required this.price});

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      name: json['name'] ?? 'منتج غير معروف',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MyOrderModel {
  final String id;
  final String status;
  final DateTime orderDate;
  final double total;
  final List<OrderItemModel> items;

  MyOrderModel({required this.id, required this.status, required this.orderDate, required this.total, required this.items});

  String get statusText {
    switch (status) {
      case 'new-order': return 'طلب جديد';
      case 'processing': return 'قيد التجهيز';
      case 'shipped': return 'تم الشحن';
      case 'delivered': return 'تم التوصيل';
      case 'cancelled': return 'ملغي';
      default: return 'مكتمل';
    }
  }
}

// --- الشاشة الرئيسية ---
class MyOrdersScreen extends StatelessWidget {
  static const String routeName = '/my_orders';
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('طلبات الجملة الخاصة بي'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF74D19C), Color(0xFF4CAF50)]),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('buyer.id', isEqualTo: user?.uid)
            .orderBy('orderDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("حدث خطأ: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("لا توجد طلبات سابقة"));
          }

          final orders = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            
            // 🟢 [حل مشكلة التاريخ هنا]
            final dynamic rawDate = data['orderDate'];
            DateTime parsedDate;
            
            if (rawDate is Timestamp) {
              parsedDate = rawDate.toDate();
            } else if (rawDate is String) {
              parsedDate = DateTime.parse(rawDate); // يحول النص "2025-12-15..." إلى DateTime
            } else {
              parsedDate = DateTime.now();
            }

            return MyOrderModel(
              id: doc.id,
              status: data['status'] ?? 'new-order',
              orderDate: parsedDate,
              total: (data['total'] as num?)?.toDouble() ?? 0.0,
              items: (data['items'] as List? ?? [])
                  .map((item) => OrderItemModel.fromJson(item))
                  .toList(),
            );
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: orders.length,
            itemBuilder: (context, index) => _OrderCard(order: orders[index]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final MyOrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(FontAwesomeIcons.fileInvoice, color: Colors.green),
        title: Text("طلب #${order.id.substring(0, 8)}", 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text("التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(order.orderDate)}"),
        children: [
          const Divider(),
          ...order.items.map((item) => ListTile(
                dense: true,
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text("الكمية: ${item.quantity}"),
                trailing: Text("${item.price} ج", style: const TextStyle(color: Colors.blueGrey)),
              )),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("إجمالي الفاتورة:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${order.total.toStringAsFixed(2)} جنيه", 
                  style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
