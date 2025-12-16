// lib/screens/consumer/consumer_purchase_history_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';

class ConsumerPurchaseHistoryScreen extends StatelessWidget {
  static const routeName = '/consumer-purchases';
  const ConsumerPurchaseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('مشترياتي الشخصية'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('consumerorders')
            .where('customerId', isEqualTo: user?.uid)
            .orderBy('orderDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("لا توجد طلبات سابقة."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              
              // 🟢 تصحيح التاريخ (حل مشكلة الشاشة الحمراء)
              final dynamic rawDate = data['orderDate'];
              DateTime date;
              if (rawDate is Timestamp) {
                date = rawDate.toDate();
              } else if (rawDate is String) {
                date = DateTime.parse(rawDate);
              } else {
                date = DateTime.now();
              }

              final String status = data['status'] ?? 'جديد';
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.receipt, color: Colors.green),
                  title: Text("طلب بتاريخ: ${DateFormat('yyyy-MM-dd').format(date)}"),
                  subtitle: Text("الحالة: $status"),
                  children: [
                    ...(data['items'] as List? ?? []).map((item) {
                      // 🟢 تصحيح السعر: جلب الحقل 'price' كما يظهر في Firestore
                      final itemPrice = item['price'] ?? item['pricePerUnit'] ?? 0;
                      return ListTile(
                        title: Text(item['name'] ?? 'منتج غير معروف'),
                        trailing: Text("$itemPrice ج"),
                        subtitle: Text("الكمية: ${item['quantity'] ?? 1}"),
                      );
                    }),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("الإجمالي النهائي:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("${data['finalAmount'] ?? 0} جنيه", 
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
      // مؤشر الطلبات هو 1 في القائمة المحدثة
      bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: 1),
    );
  }
}
