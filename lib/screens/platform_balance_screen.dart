// lib/screens/platform_balance_screen.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // لاستخدام أيقونات Font Awesome
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // 🛠️ تم إضافة استيراد debugPrint

// 🚀 إضافة استيراد شاشة الفواتير
import 'package:my_test_app/screens/invoices_screen.dart';

// 💡 تعريف الـ API Key لتطابق كود HTML.
// 🛠️ تم تصحيح الاسم ليتوافق مع قاعدة constant_identifier_names
const String apiKey = "AIzaSyAA2JbmtD52JMCz483glEV8eX1ZDeK0fZE"; 

class PlatformBalanceScreen extends StatefulWidget {
  const PlatformBalanceScreen({super.key});

  @override
  State<PlatformBalanceScreen> createState() => _PlatformBalanceScreenState();
}

class _PlatformBalanceScreenState extends State<PlatformBalanceScreen> {
  // متغيرات حالة الأرصدة
  double realizedAmount = 0.0;
  double unrealizedAmount = 0.0;
  double cashbackDebtAmount = 0.0;
  double cashbackCreditAmount = 0.0;
  bool hasPendingInvoice = false;

  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchSellerBalances();
  }

  // ----------------------------------------------------------------------
  // دالة جلب البيانات من Firestore (مطابقة لمنطق الـ HTML)
  // ----------------------------------------------------------------------
  Future<void> _fetchSellerBalances() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'الرجاء تسجيل الدخول أولاً للوصول إلى هذه الصفحة.';
        });
      }
      return;
    }

    final sellerId = user.uid;
    try {
      // 1. جلب وثيقة التاجر (Seller Doc)
      final sellerSnapshot = await FirebaseFirestore.instance
          .collection('sellers')
          .doc(sellerId)
          .get();

      if (!sellerSnapshot.exists) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'خطأ: لم يتم العثور على وثيقة بيانات لهذا التاجر في Firestore.';
          });
        }
        return;
      }

      final data = sellerSnapshot.data()!;

      // 2. استخراج الأرصدة (مطابقة لمفاتيح الـ HTML)
      // يتم التحويل إلى double بشكل صريح لأن Firestore قد يعيد int أو double
      realizedAmount = (data['realizedCommission'] as num? ?? 0).toDouble(); 
      unrealizedAmount = (data['unrealizedCommission'] as num? ?? 0).toDouble();
      cashbackDebtAmount = (data['cashbackAccruedDebt'] as num? ?? 0).toDouble();
      cashbackCreditAmount = (data['cashbackPlatformCredit'] as num? ?? 0).toDouble();

      // 3. التحقق من الفواتير المعلقة (مطابقة لمنطق الـ HTML)
      final invoicesQuery = FirebaseFirestore.instance
          .collection('invoices')
          .where('sellerId', isEqualTo: sellerId)
          .where('status', isEqualTo: 'pending');

      final pendingInvoicesSnapshot = await invoicesQuery.get();
      hasPendingInvoice = pendingInvoicesSnapshot.docs.isNotEmpty;

    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء الاتصال بقاعدة البيانات. (${e.toString()})';
      // 🛠️ تم استبدال print بـ debugPrint لتجنب avoid_print
      debugPrint('فشل جلب الأرصدة: $e'); 
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ----------------------------------------------------------------------
  // دالة تنسيق العملة (مطابقة لتنسيق HTML)
  // ----------------------------------------------------------------------
  String _formatCurrency(double amount) {
    // تتطلب حزمة intl لـ NumberFormat (للتنسيق الكامل). حالياً نستخدم تنسيق مبسط.
    return '${amount.toStringAsFixed(2)} ج.م';
  }

  // ----------------------------------------------------------------------
  // UI BUILDER
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حساب المنصة - ملخص العمولات', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF007bff), // لون أزرق مطابق لرأس الصفحة
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: _buildLoadingIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: _buildErrorWidget())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 30),
                      _buildBalanceGrid(),
                    ],
                  ),
                ),
    );
  }

  // مؤشر التحميل
  Widget _buildLoadingIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 15),
        Text(
          _errorMessage.isEmpty
              ? 'جاري التحقق من الصلاحيات وتحميل البيانات...'
              : _errorMessage,
          style: const TextStyle(fontSize: 16, color: Color(0xFF007bff)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // شاشة الخطأ
  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Text(
        _errorMessage,
        style: const TextStyle(fontSize: 18, color: Colors.red),
        textAlign: TextAlign.center,
      ),
    );
  }

  // رأس الصفحة مع رابط الفواتير
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF007bff), width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // عنوان الحساب (تم نقله إلى AppBar)
          const Text(
            'حساب المنصة - ملخص العمولات',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF007bff),
            ),
          ),

          // رابط الفواتير مع الإشعار
          InkWell(
            onTap: () {
              // ⭐️ التعديل الحاسم: الانتقال إلى شاشة الفواتير ⭐️
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InvoiceScreen(), // فتح شاشة الفواتير
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 💡 أيقونة الفاتورة (مطابقة لـ fas fa-file-invoice)
                const FaIcon(
                  FontAwesomeIcons.fileInvoice,
                  size: 30,
                  color: Color(0xFF007bff),
                ),
                // نقطة الإشعار الحمراء (مطابقة لمنطق hasPendingInvoice)
                if (hasPendingInvoice)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      height: 12,
                      width: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // شبكة بطاقات الأرصدة
  Widget _buildBalanceGrid() {
    // تعريف البطاقات الأربعة
    final cards = [
      _buildBalanceCard(
        title: 'صافي العمولة المستحقة (للمنصة)',
        amount: realizedAmount,
        bgColor: const Color(0xFFd4edda), // #d4edda
        borderColor: const Color(0xFF28a745), // #28a745
      ),
      _buildBalanceCard(
        title: 'عمولة غير محققة (قيد التجميع)',
        amount: unrealizedAmount,
        bgColor: const Color(0xFFfff3cd), // #fff3cd
        borderColor: const Color(0xFFffc107), // #ffc107
      ),
      _buildBalanceCard(
        title: 'دين الكاش باك المتراكم (عليكم)',
        amount: cashbackDebtAmount,
        bgColor: const Color(0xFFf8d7da), // #f8d7da
        borderColor: const Color(0xFFdc3545), // #dc3545
      ),
      _buildBalanceCard(
        title: 'ائتمان الكاش باك (لكم عند المنصة)',
        amount: cashbackCreditAmount,
        bgColor: const Color(0xFFcfe2ff), // #cfe2ff
        borderColor: const Color(0xFF007bff), // #007bff
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // استخدام GridView أو Column بناءً على العرض
        if (constraints.maxWidth > 600) {
          // تصميم الشاشة الكبيرة (أفقي)
          return GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.5, // لتقليل ارتفاع البطاقات
            children: cards,
          );
        } else {
          // تصميم الشاشة الصغيرة (عمودي)
          return Column(
            children: cards.map((card) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: card,
            )).toList(),
          );
        }
      },
    );
  }

  // بناء بطاقة الرصيد المفردة
  Widget _buildBalanceCard({
    required String title,
    required double amount,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: borderColor, width: 5)),
        boxShadow: [
          BoxShadow(
            // 🛠️ تم تصحيح withOpacity باستخدام قيمة ARGB ثابتة (0x0D = 0.05 * 255)
            color: const Color(0x0D000000), 
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6c757d), // #6c757d
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            _formatCurrency(amount),
            style: const TextStyle(
              fontSize: 26, // أصغر قليلاً من 2.2rem لتناسب Flutter
              fontWeight: FontWeight.bold,
              color: Color(0xFF343a40), // #343a40
            ),
          ),
        ],
      ),
    );
  }
}
