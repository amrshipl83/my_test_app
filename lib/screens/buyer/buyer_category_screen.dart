// المسار: lib/screens/buyer/buyer_category_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ المسارات الصحيحة (باستخدام اسم الحزمة my_test_app)
import 'package:my_test_app/widgets/buyer_category_header.dart';
import 'package:my_test_app/widgets/buyer_sub_categories_grid.dart';
import 'package:my_test_app/widgets/buyer_category_ads_banner.dart';

class BuyerCategoryScreen extends StatefulWidget {
  // استقبال الـ ID من الـ route arguments
  final String mainCategoryId;

  const BuyerCategoryScreen({
    super.key,
    required this.mainCategoryId,
  });

  @override
  State<BuyerCategoryScreen> createState() => _BuyerCategoryScreenState();
}

class _BuyerCategoryScreenState extends State<BuyerCategoryScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _categoryName = 'جارٍ التحميل...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategoryDetails();
  }

  // دالة جلب اسم القسم الرئيسي لعرضه في العنوان
  Future<void> _loadCategoryDetails() async {
    try {
      final docSnapshot = await _db.collection('mainCategory').doc(widget.mainCategoryId).get();
      if (docSnapshot.exists && mounted) {
        setState(() {
          _categoryName = docSnapshot.data()?['name'] ?? 'قسم غير معروف';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _categoryName = 'القسم غير موجود';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categoryName = 'خطأ في التحميل';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold هو الهيكل الأساسي للشاشة
    return Scaffold(
      // 1. استدعاء المكون الأول: Header
      appBar: BuyerCategoryHeader(
        title: _categoryName,
        isLoading: _isLoading,
      ),

      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A6491))) // لون شريط العنوان
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 2. استدعاء المكون الثاني: شبكة الأقسام الفرعية
                BuyerSubCategoriesGrid(mainCategoryId: widget.mainCategoryId),

                const SizedBox(height: 30),

                // 3. استدعاء المكون الثالث: البانر الإعلاني الصغير
                // تم حذف 'const' لتصحيح خطأ 'Not a constant expression' السابق.
                BuyerCategoryAdsBanner(), 

                const SizedBox(height: 20),

                // هنا يمكن إضافة قائمة المنتجات المرتبطة مباشرة بالقسم الرئيسي (Category Products List)
                const Center(
                  child: Text(
                    'قائمة المنتجات المرتبطة مباشرة (سيتم بناؤها لاحقاً)',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),

                const SizedBox(height: 50),
              ],
            ),
          ),

      // هنا سيتم إضافة الـ Bottom Navigation Bar لاحقًا إذا لزم الأمر
      // BottomNavigationBar: const BuyerBottomNavBar(),
    );
  }
}
