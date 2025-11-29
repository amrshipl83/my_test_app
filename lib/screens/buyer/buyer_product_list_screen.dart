// المسار: lib/screens/buyer/buyer_product_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🆕 استدعاء المكونات الجديدة
import 'package:my_test_app/widgets/buyer_product_header.dart';
import 'package:my_test_app/widgets/product_list_grid.dart';
import 'package:my_test_app/widgets/buyer_bottom_nav_bar.dart';

// 💥💥 التعديل الأول: استدعاء بانر الشركات المصنعة 💥💥
import 'package:my_test_app/widgets/manufacturers_banner.dart';

class BuyerProductListScreen extends StatefulWidget {
  final String mainCategoryId;
  final String subCategoryId;
  // 💡 [تعديل 1]: إضافة حقل اختياري لتصفية الشركات
  final String? manufacturerId;

  const BuyerProductListScreen({
    super.key,
    required this.mainCategoryId,
    required this.subCategoryId,
    // 💡 إضافة الحقل الجديد إلى المُنشئ (Constructor)
    this.manufacturerId, // تم تحديثه ليصبح اختياريًا
  });
  @override
  State<BuyerProductListScreen> createState() => _BuyerProductListScreenState();
}

class _BuyerProductListScreenState extends State<BuyerProductListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _pageTitle = 'المنتجات...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 💥💥 التصحيح لحل مشكلة التداخل: تأخير جلب التفاصيل حتى بعد بناء الإطار الأول 💥💥
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubCategoryDetails();
    });
  }

  // دالة جلب اسم القسم الفرعي
  Future<void> _loadSubCategoryDetails() async {
    try {
      final docSnapshot = await _db.collection('subCategory').doc(widget.subCategoryId).get();
      if (docSnapshot.exists && mounted) {
        setState(() {
          _pageTitle = docSnapshot.data()?['name'] ?? 'قسم فرعي غير معروف';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _pageTitle = 'القسم غير موجود';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pageTitle = 'خطأ في التحميل';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 [تحسين المظهر 1]: إضافة لون خلفية فاتح لكامل الشاشة لكسر حدة الأبيض
      backgroundColor: Colors.grey[50],
      // 1. استخدام المكون الجديد للهيدر
      appBar: BuyerProductHeader(
        title: _pageTitle,
        isLoading: _isLoading,
      ),
      // 2. تعديل الـ body لاستخدام Column
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 💥💥 التعديل الثاني: وضع بانر الشركات في الأعلى وتمرير الدالة 💥💥
          // 💡 [تحسين المظهر 2]: إزالة الـ Padding الأفقي من هنا لجعله مدمجاً بشكل كامل
          ManufacturersBanner(
            // 💡 تمرير دالة onManufacturerSelected المطلوبة
            onManufacturerSelected: (id) {
              // 💥💥 [التصحيح الوظيفي]: معالجة منطق التنقل (Push/Pop) 💥💥
              if (id == 'ALL') {
                // إذا اختار 'عرض الكل'، نتراجع خطوة واحدة (Pop) إذا كانت هناك شاشة سابقة
                // وهذا يلغي التصفية الحالية ويعود إلى الشاشة غير المفلترة.
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              } else if (id != null) {
                // إذا تم اختيار شركة حقيقية، ندفع شاشة جديدة مُفَلتَرة
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BuyerProductListScreen(
                      mainCategoryId: widget.mainCategoryId,
                      subCategoryId: widget.subCategoryId,
                      manufacturerId: id, // تمرير هوية الشركة للتصفية
                    ),
                  ),
                );
              }
            },
          ),

          // 💡 [تحسين المظهر 3]: إضافة فاصل بصري خفيف تحت البانر (اختياري)
          Divider(height: 1.0, color: Colors.grey[300]),

          // 3. تغليف شبكة المنتجات بـ Expanded لملء باقي المساحة
          Expanded(
            child: Padding(
              // 💡 [تحسين المظهر 4]: إضافة Padding متوازن لجعل محتوى الشبكة يبدو أجمل
              // الـ Padding العلوي هنا يعطي مسافة جميلة بين البانر والشبكة
              padding: const EdgeInsets.only(top: 12.0, left: 10.0, right: 10.0, bottom: 0.0),
              child: ProductListGrid(
                subCategoryId: widget.subCategoryId,
                pageTitle: _pageTitle,
                // 💡 [تعديل 3]: تمرير هوية الشركة المصنعة إلى شبكة المنتجات
                manufacturerId: widget.manufacturerId,
              ),
            ),
          ),
        ],
      ),

      // 3. شريط التنقل السفلي
      bottomNavigationBar: BuyerBottomNavBar(),
    );
  }
}
