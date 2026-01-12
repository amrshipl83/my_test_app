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

  MyOrderModel({
    required this.id,
    required this.status,
    required this.orderDate,
    required this.total,
    required this.items,
  });

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
        title: const Text('طلباتي'),
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
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }
          if (snapshot.hasError) {
            return Center(child: Text("حدث خطأ في جلب البيانات"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("لا توجد طلبات سابقة"));
          }

          final orders = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final dynamic rawDate = data['orderDate'];
            DateTime parsedDate;
            
            if (rawDate is Timestamp) {
              parsedDate = rawDate.toDate();
            } else if (rawDate is String) {
              parsedDate = DateTime.parse(rawDate);
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

  // 🎯 شريط تتبع الحالة (يظهر داخل التفاصيل)
  Widget _buildStatusTracker(String status) {
    final List<Map<String, dynamic>> stages = [
      {'key': 'new-order', 'label': 'جديد'},
      {'key': 'processing', 'label': 'تجهيز'},
      {'key': 'shipped', 'label': 'شحن'},
      {'key': 'delivered', 'label': 'استلام'},
    ];

    int currentStep = stages.indexWhere((s) => s['key'] == status);
    
    // إذا كانت الحالة ملغي لا نعرض الشريط
    if (status == 'cancelled') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10),
      child: Column(
        children: [
          Row(
            children: List.generate(stages.length, (index) {
              bool isDone = index <= currentStep;
              bool isCurrent = index == currentStep;
              return Expanded(
                child: Row(
                  children: [
                    // الدائرة
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isDone ? Colors.green : Colors.grey.shade300,
                        shape: BoxShape.circle,
                        border: isCurrent ? Border.all(color: Colors.orange, width: 2) : null,
                        boxShadow: isCurrent ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 5)] : null,
                      ),
                      child: Icon(
                        isDone ? Icons.check : Icons.circle,
                        size: 14,
                        color: isDone ? Colors.white : Colors.grey.shade500,
                      ),
                    ),
                    // الخط الواصل
                    if (index != stages.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          color: index < currentStep ? Colors.green : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stages.map((s) => Text(
              s['label'],
              style: TextStyle(
                fontSize: 10,
                fontWeight: order.status == s['key'] ? FontWeight.bold : FontWeight.normal,
                color: order.status == s['key'] ? Colors.green : Colors.grey,
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // تحديد ما إذا كان الطلب نشطاً (لم يتم تسليمه أو إلغاؤه)
    bool isActive = ['new-order', 'processing', 'shipped'].contains(order.status);
    bool isCancelled = order.status == 'cancelled';

    return Card(
      elevation: isActive ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: isActive 
            ? const BorderSide(color: Color(0xFF4CAF50), width: 1.5) 
            : BorderSide(color: Colors.grey.shade300, width: 0.5),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        leading: Icon(
          isCancelled ? Icons.cancel : FontAwesomeIcons.fileInvoice,
          color: isCancelled ? Colors.red : (isActive ? Colors.green : Colors.grey),
          size: 28,
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "طلب #${order.id.substring(0, 8)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            // عرض الحالة الحالية بجانب رقم الطلب
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCancelled ? Colors.red.withOpacity(0.1) : (isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                order.statusText,
                style: TextStyle(
                  color: isCancelled ? Colors.red : (isActive ? Colors.green : Colors.grey.shade700),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          "بتاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(order.orderDate)}",
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          const Divider(height: 1),
          
          // 🎯 عرض شريط التتبع للطلبات غير المنتهية فقط
          if (isActive) _buildStatusTracker(order.status),
          
          if (isActive) const Divider(height: 1),

          // قائمة المنتجات
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: order.items.map((item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text("الكمية: ${item.quantity}"),
                trailing: Text("${(item.price * item.quantity).toStringAsFixed(2)} ج", 
                  style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              )).toList(),
            ),
          ),
          
          const Divider(height: 1),
          
          // إجمالي الفاتورة
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("إجمالي الفاتورة:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  "${order.total.toStringAsFixed(2)} جنيه",
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

