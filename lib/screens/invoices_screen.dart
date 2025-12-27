// lib/screens/invoices_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_test_app/screens/invoice_details_screen.dart';

class InvoiceScreen extends StatefulWidget {
  final String? sellerId;
  const InvoiceScreen({super.key, this.sellerId});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  // جلب الفواتير عبر الـ Stream لضمان التحديث اللحظي
  Stream<QuerySnapshot> _fetchInvoices() {
    final uid = widget.sellerId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('invoices')
        .where('sellerId', isEqualTo: uid)
        .orderBy('creationDate', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    // تم إزالة Directionality والاعتماد على الثيم العام للتطبيق
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف الفواتير الشهرية'),
        backgroundColor: const Color(0xFF007bff),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchInvoices(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("حدث خطأ أثناء جلب البيانات: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("لا توجد فواتير سابقة لعرضها."));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String docId = docs[index].id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Color(0xFF007bff)),
                  title: Text(
                    "فاتورة شهر ${_formatDate(data['creationDate'])}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "إجمالي المبلغ: ${_formatCurrency(data['finalAmount'])}",
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // الانتقال لصفحة التفاصيل وتمرير البيانات
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InvoiceDetailsScreen(
                          invoiceId: docId,
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
    );
  }

  // تنسيق العملة
  String _formatCurrency(dynamic amount) {
    final formatter = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م');
    return formatter.format((amount as num? ?? 0).toDouble());
  }

  // تنسيق التاريخ
  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat.yMMMM('ar_EG').format(ts.toDate());
    }
    return ts.toString();
  }
}

