// lib/screens/invoices_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_test_app/screens/invoice_details_screen.dart'; // تأكد من إنشاء هذا الملف

class InvoiceScreen extends StatefulWidget {
  final String? sellerId;
  const InvoiceScreen({super.key, this.sellerId});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  // منطق جلب الفواتير (مطابق للـ HTML)
  Stream<QuerySnapshot> _fetchInvoices() {
    final uid = widget.sellerId ?? FirebaseAuth.instance.currentUser?.uid;
    return FirebaseFirestore.instance
        .collection('invoices')
        .where('sellerId', isEqualTo: uid)
        .orderBy('creationDate', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كشف الفواتير الشهرية'),
          backgroundColor: const Color(0xFF007bff),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _fetchInvoices(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text("خطأ: ${snapshot.error}"));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const Center(child: Text("لا توجد فواتير."));

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final id = docs[index].id;

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text("فاتورة ${_formatDate(data['creationDate'])}"),
                    subtitle: Text("المبلغ: ${data['finalAmount']} ج.م"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // 🎯 الانتقال لصفحة التفاصيل وتمرير البيانات
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InvoiceDetailsScreen(
                            invoiceId: id,
                            invoiceData: data,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) return DateFormat.yMMMd('ar_EG').format(ts.toDate());
    return ts.toString();
  }
}

