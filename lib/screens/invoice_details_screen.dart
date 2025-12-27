// lib/screens/invoice_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  final String invoiceId;
  final Map<String, dynamic> invoiceData;

  const InvoiceDetailsScreen({
    super.key, 
    required this.invoiceId, 
    required this.invoiceData
  });

  @override
  Widget build(BuildContext context) {
    // تم حذف Directionality للاعتماد على الثيم العام في main.dart
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الفاتورة'),
        backgroundColor: const Color(0xFF007bff),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 30),
            _buildInfoTile("رقم الفاتورة المرجعي", invoiceId.substring(0, 8).toUpperCase()),
            _buildInfoTile("إجمالي العمولة", "${invoiceData['totalCommission'] ?? 0} ج.م"),
            _buildInfoTile("صافي المبلغ المطلوب", "${invoiceData['finalAmount'] ?? 0} ج.م"),
            const Divider(height: 40),
            _buildStatusRow(),
            const Spacer(),
            if (invoiceData['status'] != 'paid')
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () { 
                    // منطق بوابة الدفع سيضاف هنا لاحقاً
                  },
                  child: const Text(
                    "سداد الفاتورة الآن", 
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    bool isPaid = invoiceData['status'] == 'paid';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPaid ? Colors.green : Colors.orange),
      ),
      child: Row(
        children: [
          Icon(isPaid ? Icons.check_circle : Icons.pending_actions, color: isPaid ? Colors.green : Colors.orange),
          const SizedBox(width: 10),
          Text(
            isPaid ? "هذه الفاتورة مسددة بالكامل" : "هذه الفاتورة بانتظار السداد",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPaid ? Colors.green.shade900 : Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    bool isPaid = invoiceData['status'] == 'paid';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("حالة الفاتورة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPaid ? Colors.green : Colors.orange,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isPaid ? "تم السداد" : "قيد الانتظار",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    );
  }
}

