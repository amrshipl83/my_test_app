// lib/screens/platform_balance_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_test_app/screens/invoices_screen.dart'; // 🎯 الصفحة المستهدفة
import 'package:sizer/sizer.dart';

class PlatformBalanceScreen extends StatefulWidget {
  const PlatformBalanceScreen({super.key});

  @override
  State<PlatformBalanceScreen> createState() => _PlatformBalanceScreenState();
}

class _PlatformBalanceScreenState extends State<PlatformBalanceScreen> {
  double realizedAmount = 0.0;      // عمولة مستحقة للمنصة
  double unrealizedAmount = 0.0;    // عمولة تحت التحصيل
  double cashbackDebtAmount = 0.0;  // مديونية كاش باك (على التاجر)
  double cashbackCreditAmount = 0.0;// ائتمان كاش باك (للتاجر)
  bool hasPendingInvoice = false;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchSellerBalances();
  }

  // دالة جلب البيانات من Firestore
  Future<void> _fetchSellerBalances() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // جلب وثيقة التاجر
      final sellerSnapshot = await FirebaseFirestore.instance
          .collection('sellers')
          .doc(user.uid)
          .get();

      if (sellerSnapshot.exists) {
        final data = sellerSnapshot.data()!;
        setState(() {
          realizedAmount = (data['realizedCommission'] as num? ?? 0).toDouble();
          unrealizedAmount = (data['unrealizedCommission'] as num? ?? 0).toDouble();
          cashbackDebtAmount = (data['cashbackAccruedDebt'] as num? ?? 0).toDouble();
          cashbackCreditAmount = (data['cashbackPlatformCredit'] as num? ?? 0).toDouble();
        });
      }

      // التحقق من وجود فواتير معلقة (نفس منطق الـ HTML)
      final invoicesQuery = await FirebaseFirestore.instance
          .collection('invoices')
          .where('sellerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() => hasPendingInvoice = invoicesQuery.docs.isNotEmpty);
    } catch (e) {
      setState(() => _errorMessage = 'خطأ في جلب البيانات');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // دالة الانتقال الآمن لصفحة الفواتير
  void _navigateToInvoices() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceScreen(sellerId: user.uid), // تمرير المعرف بأمان
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF007bff),
          title: Text('الحساب المالي للمنصة', 
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: IconButton(
                icon: const FaIcon(FontAwesomeIcons.receipt, color: Colors.white),
                onPressed: _navigateToInvoices, // استدعاء دالة الانتقال الآمن
                tooltip: 'الفواتير الشهرية',
              ),
            )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(5.w),
                child: Column(
                  children: [
                    _buildAlertBanner(),
                    SizedBox(height: 2.h),
                    _buildBalanceCard(
                      "عمولات مستحقة للمنصة", 
                      realizedAmount, 
                      "رسوم الطلبات المسلمة فعلياً", 
                      const Color(0xFF28a745), 
                      FontAwesomeIcons.calculator
                    ),
                    _buildBalanceCard(
                      "عمولات قيد المعالجة", 
                      unrealizedAmount, 
                      "طلبات لم يكتمل تسليمها بعد", 
                      const Color(0xFFffc107), 
                      FontAwesomeIcons.hourglassHalf
                    ),
                    const Divider(height: 40, thickness: 1),
                    _buildBalanceCard(
                      "مديونية كاش باك (عليكم)", 
                      cashbackDebtAmount, 
                      "فرق كاش باك لمورد آخر", 
                      const Color(0xFFdc3545), 
                      FontAwesomeIcons.arrowDown
                    ),
                    _buildBalanceCard(
                      "ائتمان كاش باك (لكم)", 
                      cashbackCreditAmount, 
                      "تعويض كاش باك من المنصة", 
                      const Color(0xFF007bff), 
                      FontAwesomeIcons.arrowUp
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAlertBanner() {
    if (!hasPendingInvoice) return const SizedBox();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              "توجد فاتورة شهرية مستحقة الدفع حالياً. يرجى المراجعة.",
              style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 11.sp),
            ),
          ),
          TextButton(
            onPressed: _navigateToInvoices, // استدعاء دالة الانتقال الآمن
            child: const Text("عرض", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String title, double amount, String desc, Color color, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: FaIcon(icon, color: color, size: 20),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                Text(desc, style: TextStyle(color: Colors.grey, fontSize: 10.sp)),
              ],
            ),
          ),
          Text(
            "${amount.toStringAsFixed(2)} ج.م",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: color),
          ),
        ],
      ),
    );
  }
}

