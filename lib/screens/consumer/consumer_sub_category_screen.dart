// lib/screens/consumer/consumer_sub_category_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../../models/category_model.dart';
import '../../services/marketplace_data_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/theme_notifier.dart'; // لتغيير الثيم
import '../../providers/cart_provider.dart';  // لحساب السلة
// 🟢🟢 [الإضافة الجديدة]: استيراد مسار شاشة المنتجات الجديدة 🟢🟢
// تم تصحيح الاستيراد ليكون مطلقاً لحل مشكلة 'No such file or directory'
import 'package:my_test_app/screens/consumer/ConsumerProductListScreen.dart'; 

class ConsumerSubCategoryScreen extends StatefulWidget {
  final String mainCategoryId;
  final String ownerId;
  final String mainCategoryName;
  static const routeName = '/subcategories';

  const ConsumerSubCategoryScreen({
    super.key,
    required this.mainCategoryId,
    required this.ownerId,
    required this.mainCategoryName,
  });

  @override
  State<ConsumerSubCategoryScreen> createState() => _ConsumerSubCategoryScreenState();
}

class _ConsumerSubCategoryScreenState extends State<ConsumerSubCategoryScreen> {
  late Future<List<CategoryModel>> _subCategoriesFuture;
  final MarketplaceDataService _dataService = MarketplaceDataService();

  @override
  void initState() {
    super.initState();
    // 💡 بدلاً من loadSubCategories() في JavaScript، نستدعي دالة الخدمة هنا
    _subCategoriesFuture = _dataService.fetchSubCategoriesByOffers(
      widget.mainCategoryId,
      widget.ownerId,
    );
  }

  // 🎯🎯 [التعديل الرئيسي]: توجيه المستخدم لصفحة منتجات المستهلك 🎯🎯
  void _navigateToProductList(BuildContext context, CategoryModel subCategory) {
    Navigator.of(context).pushNamed(
      ConsumerProductListScreen.routeName, // ⬅️ المسار الجديد الذي يفتح شاشة المستهلك
      arguments: {
        'mainId': widget.mainCategoryId,
        'subId': subCategory.id,
        'ownerId': widget.ownerId,
        'subCategoryName': subCategory.name, // تمرير اسم القسم لاستخدامه كعنوان
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // لقراءة حالة السلة والثيم (مثل JavaScript)
    final cartProvider = Provider.of<CartProvider>(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      appBar: AppBar(
        // 💡 يحاكي .top-header والـ page-title
        title: Text(widget.mainCategoryName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(), // زر الرجوع
        ),
        actions: [
          // 💡 يحاكي .theme-toggle (زر تفعيل الثيم)
          IconButton(
            icon: Icon(themeNotifier.isDarkMode ? Icons.wb_sunny : Icons.dark_mode),
            onPressed: themeNotifier.toggleTheme,
          ),
        ],
      ),
      body: FutureBuilder<List<CategoryModel>>(
        future: _subCategoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 💡 يحاكي .loading في HTML
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryGreen),
                  const SizedBox(height: 20),
                  Text('جاري تحميل الأقسام الفرعية...', style: TextStyle(color: AppTheme.primaryGreen)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            // 💡 يحاكي رسالة الخطأ في HTML
            return Center(child: Text('حدث خطأ: ${snapshot.error.toString()}', textAlign: TextAlign.center));
          }

          final subCategories = snapshot.data ?? [];

          if (subCategories.isEmpty) {
            return const Center(child: Text('لا توجد أقسام فرعية نشطة حاليًا.'));
          }

          // 💡 يحاكي .categories-grid في HTML
          return GridView.builder(
            padding: EdgeInsets.all(4.w),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: SizerUtil.orientation == Orientation.portrait ? 2 : 3, // 2 أو 3 أعمدة
              childAspectRatio: 0.85,
              crossAxisSpacing: 4.w,
              mainAxisSpacing: 4.w,
            ),
            itemCount: subCategories.length,
            itemBuilder: (context, index) {
              final category = subCategories[index];
              return _buildCategoryCard(context, category);
            },
          );
        },
      ),
      // 💡 يحاكي .bottom-nav
      // *ملاحظة*: يجب أن يكون لديك BottomNavigationBar منفصل أو يجب استخدامه من الشاشات الرئيسية
      // في هذا المثال سنعتمد على التصميم القياسي للسكرين (أو يجب استيراد الـ Widget الخاص بالـ Nav Bar)
    );
  }

  Widget _buildCategoryCard(BuildContext context, CategoryModel category) {
    return InkWell(
      onTap: () => _navigateToProductList(context, category), // 🚨 أهم جزء: الضغط ينقل للـ products
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15.0),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 💡 يحاكي .category-card img
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15.0)),
                child: category.imageUrl.isNotEmpty
                    ? Image.network(
                        category.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.category, size: 50, color: Colors.grey),
                      )
                    : const Icon(Icons.category, size: 50, color: Colors.grey),
              ),
            ),
            // 💡 يحاكي .category-name
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 10.sp, // استخدام Sizer
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
