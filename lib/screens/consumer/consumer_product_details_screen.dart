// lib/screens/consumer/consumer_product_details_screen.dart

import 'package:flutter/material.dart';

// شاشة افتراضية ومؤقتة لعرض تفاصيل المنتج للمستهلك
class ConsumerProductDetailsScreen extends StatelessWidget {
  
  // 🎯 [حل الخطأ رقم 3]: إضافة المسار الثابت المطلوب
  static const routeName = '/consumerProductDetails';

  // نحتاج هذه الوسائط لكي لا يفشل الاستدعاء من شاشة القائمة
  final String productId;
  final String offerId;

  const ConsumerProductDetailsScreen({
    super.key,
    // يجب أن تكون الوسائط مطلوبة ليتطابق التوقيع مع الاستدعاء
    required this.productId,
    required this.offerId, 
  });
  
  // دالة Factory لقراءة الوسائط عند التوجيه (كما هو مطلوب عادةً)
  factory ConsumerProductDetailsScreen.fromRoute(BuildContext context) {
    // قراءة الوسائط المرسلة
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
    return ConsumerProductDetailsScreen(
      productId: args?['productId'] ?? 'N/A',
      offerId: args?['offerId'] ?? 'N/A',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل المنتج (تحت الإنشاء)'),
          backgroundColor: Colors.blueGrey, 
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build_circle, size: 50, color: Colors.blueGrey),
                const SizedBox(height: 20),
                const Text(
                  'هذه صفحة تفاصيل المنتج الخاصة بالمستهلك وهي قيد الإنشاء حاليًا.', 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text('تم التوجيه بنجاح باستخدام:', style: TextStyle(color: Colors.grey[700])),
                Text('Product ID: $productId', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Offer ID: $offerId', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
