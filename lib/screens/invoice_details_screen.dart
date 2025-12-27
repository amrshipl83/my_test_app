// lib/screens/invoice_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  final String invoiceId;
  final Map<String, dynamic> invoiceData;

  const InvoiceDetailsScreen({super.key, required this.invoiceId, required this.invoiceData});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الفاتورة')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildInfoTile("رقم الفاتورة", invoiceId),
              _buildInfoTile("إجمالي العمولة", "${invoiceData['totalCommission']} ج.م"),
              _buildInfoTile("صافي المبلغ المطلوب", "${invoiceData['finalAmount']} ج.م"),
              _buildInfoTile("حالة السداد", invoiceData['status'] == 'paid' ? "تم السداد" : "قيد الانتظار"),
              const Spacer(),
              if (invoiceData['status'] != 'paid')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () { /* منطق بوابة الدفع */ },
                    child: const Text("سداد الآن", style: TextStyle(color: Colors.white)),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}

