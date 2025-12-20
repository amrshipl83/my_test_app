// lib/screens/consumer/consumer_sub_category_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    // جلب الأقسام الفرعية بناءً على عروض التاجر الحالي
    _subCategoriesFuture = _dataService.fetchSubCategoriesByOffers(
      widget.mainCategoryId,
      widget.ownerId,
    );
  }

  // دالة جلب البانر الذكي: يبحث عن إعلان التاجر أولاً ثم الإعلانات العامة
  Future<Map<String, dynamic>?> _getBanner() async {
    try {
      // 1. محاولة جلب إعلان خاص بهذا التاجر
      var dealerBanner = await FirebaseFirestore.instance
          .collection('consumerBanners')
          .where('ownerId', isEqualTo: widget.ownerId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (dealerBanner.docs.isNotEmpty) {
        return dealerBanner.docs.first.data();
      }

      // 2. إذا لم يوجد، جلب إعلان عام (Target: general)
      var generalBanner = await FirebaseFirestore.instance
          .collection('consumerBanners')
          .where('targetAudience', isEqualTo: 'general')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (generalBanner.docs.isNotEmpty) {
        return generalBanner.docs.first.data();
      }
    } catch (e) {
      debugPrint("Error fetching banner: $e");
    }
    return null;
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
              Text("متجر: ${widget.ownerId.substring(0, 5)}...", 
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
            // 1. البانر الإعلاني الديناميكي
            SliverToBoxAdapter(
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _getBanner(),
                builder: (context, bannerSnapshot) {
                  final bannerData = bannerSnapshot.data;
                  final String bannerImg = bannerData?['imageUrl'] ?? "";
                  final String bannerName = bannerData?['name'] ?? "عروض خاصة";

                  return Container(
                    height: 18.h,
                    margin: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      image: bannerImg.isNotEmpty 
                          ? DecorationImage(
                              image: NetworkImage(bannerImg),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.darken),
                            ) 
                          : null,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: bannerImg.isEmpty && bannerSnapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : Padding(
                            padding: EdgeInsets.all(5.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(bannerName, 
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                                Text("اكتشف أفضل الأسعار اليوم", 
                                  style: TextStyle(color: Colors.white70, fontSize: 10.sp)),
                              ],
                            ),
                          ),
                  );
                },
              ),
            ),

            // 2. شبكة الأقسام الفرعية
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
                // 🛑 تم التصحيح: استخدام itemCount المعرف في CartProvider.dart 🛑
                label: Text(cartProvider.itemCount.toString()), 
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
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
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
              child: Text(category.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp)),
            ),
          ],
        ),
      ),
    );
  }
}
