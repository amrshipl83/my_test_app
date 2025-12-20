// lib/screens/consumer/consumer_sub_category_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../../models/category_model.dart';
import '../../services/marketplace_data_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/cart_provider.dart';
import 'package:my_test_app/screens/consumer/ConsumerProductListScreen.dart';
import 'package:my_test_app/screens/consumer/consumer_home_screen.dart';

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
    _subCategoriesFuture = _dataService.fetchSubCategoriesByOffers(
      widget.mainCategoryId,
      widget.ownerId,
    );
  }

  void _navigateToProductList(BuildContext context, CategoryModel subCategory) {
    Navigator.of(context).pushNamed(
      ConsumerProductListScreen.routeName,
      arguments: {
        'mainId': widget.mainCategoryId,
        'subId': subCategory.id,
        'ownerId': widget.ownerId,
        'subCategoryName': subCategory.name,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final screenOrientation = MediaQuery.of(context).orientation;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          centerTitle: true,
          title: Column(
            children: [
              Text(widget.mainCategoryName, 
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
              Text("متجر: ${widget.ownerId.substring(0,5)}...", 
                style: TextStyle(fontSize: 9.sp, color: Colors.grey)),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 18.h,
                margin: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryGreen, Colors.greenAccent],
                  ),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Stack(
                  children: [
                    Positioned(left: -20, top: -20, child: Icon(Icons.stars, size: 100, color: Colors.white10)),
                    Padding(
                      padding: EdgeInsets.all(5.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("عروض خاصة داخل هذا القسم", 
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                          Text("اكتشف أفضل الأسعار اليوم في ${widget.mainCategoryName}", 
                            style: TextStyle(color: Colors.white70, fontSize: 10.sp)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            FutureBuilder<List<CategoryModel>>(
              future: _subCategoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                }
                final subCategories = snapshot.data ?? [];
                if (subCategories.isEmpty) {
                  return const SliverFillRemaining(child: Center(child: Text('لا توجد أقسام حاليًا.')));
                }
                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: screenOrientation == Orientation.portrait ? 2 : 3,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 4.w,
                      mainAxisSpacing: 4.w,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildCategoryCard(context, subCategories[index]),
                      childCount: subCategories.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryGreen,
          unselectedItemColor: Colors.grey,
          currentIndex: 0,
          onTap: (index) {
            if (index == 0) Navigator.pushNamed(context, ConsumerHomeScreen.routeName);
          },
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'الرئيسية'),
            BottomNavigationBarItem(
              icon: Badge(
                // 🛑 تم تصحيح الخطأ هنا: استخدام items.length 🛑
                label: Text(cartProvider.items.length.toString()),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              label: 'سلتك',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.wallet_outlined), label: 'محفظتي'),
            const BottomNavigationBarItem(icon: Icon(Icons.history_edu_rounded), label: 'طلباتي'),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, CategoryModel category) {
    return InkWell(
      onTap: () => _navigateToProductList(context, category),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: category.imageUrl.isNotEmpty
                    ? Image.network(category.imageUrl, fit: BoxFit.cover, width: double.infinity)
                    : Container(color: Colors.grey.shade50, child: const Icon(Icons.category, color: Colors.grey)),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(3.w),
              child: Text(category.name, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp)),
            ),
          ],
        ),
      ),
    );
  }
}
