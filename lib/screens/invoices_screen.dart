// lib/screens/invoices_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_test_app/screens/invoice_details_screen.dart'; // تأكد من المسار الصحيح
import 'package:my_test_app/services/user_session.dart'; 
import 'package:sizer/sizer.dart';

class InvoiceScreen extends StatefulWidget {
  final String? sellerId;
  const InvoiceScreen({super.key, this.sellerId});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  // ✅ التعديل الأول: جلب البيانات من الكوليكشن الصحيح (pendingInvoices)
  Stream<QuerySnapshot> _fetchInvoices() {
    final String? uid = widget.sellerId ??
        ((UserSession.ownerId != null && UserSession.ownerId!.isNotEmpty)
            ? UserSession.ownerId
            : FirebaseAuth.instance.currentUser?.uid);

    if (uid == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('pendingInvoices') // 👈 تم تغيير المسار هنا
        .where('sellerId', isEqualTo: uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text('الفواتير المستحقة', // اسم أنسب للحالة الجديدة
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16.sp)),
        backgroundColor: const Color(0xFF007bff),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchInvoices(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("خطأ في جلب البيانات"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text("لا توجد فواتير معلقة", style: TextStyle(fontFamily: 'Cairo')));

          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              
              return Card(
                elevation: 2,
                margin: EdgeInsets.only(bottom: 1.5.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(
                    "فاتورة رقم: ${docs[index].id.substring(0,6).toUpperCase()}",
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ التعديل الثاني: استخدام createdAt و amount حسب صورة الداتابيز
                      Text("تاريخ: ${_formatDate(data['createdAt'])}", style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      Text(
                        "المبلغ: ${_formatCurrency(data['amount'])}",
                        style: const TextStyle(fontFamily: 'Cairo', color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  trailing: _buildStatusBadge(data['status']),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InvoiceDetailsScreen(
                          invoiceId: docs[index].id,
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

  // ودجت صغيرة لإظهار حالة الفاتورة في القائمة
  Widget _buildStatusBadge(String? status) {
    Color color = Colors.orange;
    String text = "انتظار";
    if (status == 'paid') { color = Colors.green; text = "تم الدفع"; }
    if (status == 'cash_collection') { color = Colors.blue; text = "كاش"; }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  String _formatCurrency(dynamic amount) {
    double value = 0.0;
    if (amount is num) value = amount.toDouble();
    else if (amount is String) value = double.tryParse(amount) ?? 0.0;
    return "${value.toStringAsFixed(2)} ج.م";
  }

  String _formatDate(dynamic dateVal) {
    try {
      if (dateVal == null) return "بدون تاريخ";
      DateTime dt;
      if (dateVal is Timestamp) dt = dateVal.toDate();
      else if (dateVal is String) dt = DateTime.parse(dateVal);
      else return "تاريخ غير معروف";
      
      return DateFormat('yyyy/MM/dd HH:mm', 'ar_EG').format(dt);
    } catch (e) {
      return "خطأ في التاريخ";
    }
  }
}
