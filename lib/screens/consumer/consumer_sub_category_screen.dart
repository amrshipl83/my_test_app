import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/category_model.dart';
import '../../services/marketplace_data_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/cart_provider.dart';
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
    _subCategoriesFuture = _dataService.fetchSubCategoriesByOffers(
      widget.mainCategoryId,
      widget.ownerId,
    );
  }

  Future<Map<String, dynamic>?> _getBanner() async {
    try {
      var dealerBanner = await FirebaseFirestore.instance
          .collection('consumerBanners')
          .where('ownerId', isEqualTo: widget.ownerId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (dealerBanner.docs.isNotEmpty) return dealerBanner.docs.first.data();

      var generalBanner = await FirebaseFirestore.instance
          .collection('consumerBanners')
          .where('targetAudience', isEqualTo: 'general')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (generalBanner.docs.isNotEmpty) return generalBanner.docs.first.data();
    } catch (e) {
      debugPrint("Error fetching banner: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF2D3142),
          centerTitle: true,
          toolbarHeight: 8.h,
          title: Text(widget.mainCategoryName,
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. البانر الإعلاني المحسن
            SliverToBoxAdapter(
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _getBanner(),
                builder: (context, bannerSnapshot) {
                  final bannerData = bannerSnapshot.data;
                  final String bannerImg = bannerData?['imageUrl'] ?? "";
                  
                  return Container(
                    height: 20.h,
                    margin: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: bannerImg.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(bannerImg, fit: BoxFit.cover),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                                      begin: Alignment.bottomCenter,
                                    ),
                                  ),
                                  padding: EdgeInsets.all(4.w),
                                  alignment: Alignment.bottomRight,
                                  child: Text(bannerData?['name'] ?? "عروض حصرية",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                                ),
                              ],
                            )
                          : const Center(child: Icon(Icons.image, color: Colors.grey)),
                    ),
                  );
                },
              ),
            ),

            // 2. شبكة الأقسام الفرعية بكروت "بريميوم"
            FutureBuilder<List<CategoryModel>>(
              future: _subCategoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                }
                final subCategories = snapshot.data ?? [];
                
                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 4.w,
                      mainAxisSpacing: 4.w,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildPremiumCategoryCard(context, subCategories[index]),
                      childCount: subCategories.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: _buildModernBottomNav(context, cartProvider),
      ),
    );
  }

  Widget _buildPremiumCategoryCard(BuildContext context, CategoryModel category) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        ConsumerProductListScreen.routeName,
        arguments: {
          'mainId': widget.mainCategoryId,
          'subId': category.id,
          'ownerId': widget.ownerId,
          'subCategoryName': category.name,
        },
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  // تحسين تناسق الصورة مع الإطار
                  child: Image.network(category.imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 2.h),
              child: Text(category.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.sp, color: const Color(0xFF2D3142))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBottomNav(BuildContext context, CartProvider cart) {
    return Container(
      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]),
      child: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppTheme.primaryGreen,
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_filled, size: 28), label: 'الرئيسية'),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(cart.itemCount.toString()),
              isLabelVisible: cart.itemCount > 0,
              child: const Icon(Icons.shopping_basket_rounded, size: 28),
            ),
            label: 'سلتك',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded, size: 28), label: 'محفظتي'),
          const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded, size: 28), label: 'طلباتي'),
        ],
        onTap: (index) {
          if (index == 0) Navigator.popUntil(context, (route) => route.isFirst);
          if (index == 1) Navigator.pushNamed(context, '/cart');
          if (index == 2) Navigator.pushNamed(context, '/points-loyalty');
          if (index == 3) Navigator.pushNamed(context, '/orders');
        },
      ),
    );
  }
}

