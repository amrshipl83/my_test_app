// lib/screens/seller/create_gift_promo_screen.dart

import 'package:flutter/material.dart';

class CreateGiftPromoScreen extends StatelessWidget {
  // 💡 الحقل الجديد المطلوب ليقبل قيمة currentSellerId من seller_sidebar.dart
  final String currentSellerId;
  
  // 🛠️ تم تعديل المنشئ ليقبل currentSellerId كـ required
  const CreateGiftPromoScreen({
    super.key, 
    required this.currentSellerId,
  });

  @override
  Widget build(BuildContext context) {
    // 💡 الآن يمكنك استخدام currentSellerId داخل الشاشة
    // Text('البائع الحالي: $currentSellerId')
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء عرض هدايا/ترويج'),
      ),
      body: Center(
        child: Text('شاشة إنشاء العرض الترويجي للبائع ID: $currentSellerId'),
      ),
    );
  }
}
