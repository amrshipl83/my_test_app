import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // تأكد من إضافة هذه المكتبة في pubspec.yaml

class InvoiceDetailsScreen extends StatelessWidget {
  final String invoiceId;
  final Map<String, dynamic> invoiceData;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
    required this.invoiceData
  });

  // دالة لفتح رابط الدفع في المتصفح الخارجي
  Future<void> _openPaymentLink(BuildContext context) async {
    final String? link = invoiceData['paymentLink']; // سحب الرابط من حقل paymentLink في Firestore

    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عذراً، رابط الدفع غير متوفر حالياً')),
      );
      return;
    }

    final Uri url = Uri.parse(link);
    
    try {
      // محاولة فتح الرابط في متصفح خارجي لضمان الأمان والتوافق
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء محاولة فتح بوابة الدفع')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isPaid = invoiceData['status'] == 'paid';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الفاتورة'),
        backgroundColor: const Color(0xFF007bff),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 25),
            
            _buildSectionTitle("البيانات الأساسية"),
            _buildInfoTile("رقم الفاتورة المرجعي", invoiceId.substring(0, 8).toUpperCase()),
            _buildInfoTile("تاريخ الإصدار", _formatDate(invoiceData['creationDate'])),
            if (invoiceData['paymentDate'] != null)
              _buildInfoTile("تاريخ السداد", _formatDate(invoiceData['paymentDate'])),
            
            const Divider(height: 40),
            
            _buildSectionTitle("التفاصيل المالية"),
            _buildInfoTile("إجمالي العمولة", "${invoiceData['totalCommission'] ?? 0} ج.م"),
            _buildInfoTile("الضريبة المضافة", "${invoiceData['vatAmount'] ?? 0} ج.م"),
            _buildInfoTile("صافي المبلغ المطلوب", "${invoiceData['finalAmount'] ?? 0} ج.م", isBold: true),
            
            const Divider(height: 40),
            
            _buildStatusRow(),
            if (invoiceData['paymentMethod'] != null)
              _buildInfoTile("طريقة السداد", "${invoiceData['paymentMethod']}"),

            const SizedBox(height: 40),

            // زرار الدفع يظهر فقط إذا كانت الحالة ليست paid
            if (!isPaid)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.payment, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: () => _openPaymentLink(context), // استدعاء دالة الفتح
                  label: const Text(
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

  // الدوال المساعدة (Helper Methods) دون تغيير كبير لتوافق التصميم السابق
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
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
          Icon(isPaid ? Icons.check_circle : Icons.pending_actions, 
               color: isPaid ? Colors.green : Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPaid ? "هذه الفاتورة مسددة بالكامل" : "هذه الفاتورة بانتظار السداد",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPaid ? Colors.green.shade900 : Colors.orange.shade900,
              ),
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

  Widget _buildInfoTile(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          Text(value, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600, 
            fontSize: isBold ? 16 : 15,
            color: isBold ? Colors.green.shade700 : Colors.black87
          )),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return "غير متوفر";
    try {
      if (dateVal is String) {
        DateTime dt = DateTime.parse(dateVal);
        return DateFormat('yyyy/MM/dd').format(dt);
      }
      return DateFormat('yyyy/MM/dd').format(dateVal.toDate());
    } catch (e) {
      return dateVal.toString();
    }
  }
}
