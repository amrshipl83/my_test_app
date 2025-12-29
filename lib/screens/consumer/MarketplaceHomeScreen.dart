import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/services/marketplace_data_service.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/models/banner_model.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import '../../theme/app_theme.dart';

class MarketplaceHomeScreen extends StatefulWidget {
  static const routeName = '/marketplaceHome';
  final String currentStoreId;
  final String currentStoreName;

  const MarketplaceHomeScreen({
    super.key,
    required this.currentStoreId,
    required this.currentStoreName,
  });

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> {
  final MarketplaceDataService _dataService = MarketplaceDataService();
  late Future<List<BannerModel>> _bannersFuture;
  late Future<List<CategoryModel>> _categoriesFuture;
  late PageController _bannerPageController;
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _bannersFuture = _dataService.fetchBanners(widget.currentStoreId);
    _categoriesFuture = _dataService.fetchCategoriesByOffers(widget.currentStoreId);
    _bannerPageController = PageController();
  }

  @override
  void dispose() {
    _bannerPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyerProvider = Provider.of<BuyerDataProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final welcomeName = buyerProvider.userName ?? 'عميلنا العزيز';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA), // خلفية فاتحة مريحة
        appBar: _buildCleanAppBar(welcomeName),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. قسم البانرات (Slider) - تم وضعه في الأعلى كواجهة جذب
            SliverToBoxAdapter(child: _buildEnhancedBannerSlider()),

            // 2. عنوان "الأقسام الرئيسية" بخط كبير وواضح
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("الأقسام الرئيسية",
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: const Color(0xFF2D3142))),
                    Text("عرض الكل", style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            // 3. شبكة الأقسام بكروت محسنة
            _buildPremiumCategoriesGrid(),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
        // البار السفلي المحدث (بدون بحث)
        bottomNavigationBar: _buildModernBottomNav(cartProvider),
      ),
    );
  }

  PreferredSizeWidget _buildCleanAppBar(String name) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 9.h,
      automaticallyImplyLeading: false, // حذف سهم الرجوع لو كانت هي الصفحة الرئيسية
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primaryGreen, width: 2)),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
              child: Icon(Icons.person, color: AppTheme.primaryGreen, size: 28),
            ),
          ),
          SizedBox(width: 4.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("مرحباً بك، $name", 
                style: TextStyle(fontSize: 13.sp, color: const Color(0xFF2D3142), fontWeight: FontWeight.bold)),
              Text(widget.currentStoreName, 
                style: TextStyle(fontSize: 10.sp, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedBannerSlider() {
    return FutureBuilder<List<BannerModel>>(
      future: _bannersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 22.h,
          margin: EdgeInsets.only(top: 2.h),
          child: PageView.builder(
            controller: _bannerPageController,
            itemCount: snapshot.data!.length,
            onPageChanged: (i) => setState(() => _currentBannerIndex = i),
            itemBuilder: (context, index) {
              final banner = snapshot.data![index];
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                  image: DecorationImage(image: NetworkImage(banner.imageUrl), fit: BoxFit.cover),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPremiumCategoriesGrid() {
    return FutureBuilder<List<CategoryModel>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        }
        final categories = snapshot.data ?? [];
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 4.w,
              mainAxisSpacing: 4.w,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cat = categories[index];
                return GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed('/subcategories', arguments: {
                    'mainId': cat.id,
                    'ownerId': widget.currentStoreId,
                    'mainCategoryName': cat.name,
                  }),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(cat.imageUrl, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 2.h),
                          child: Text(cat.name, 
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: const Color(0xFF2D3142))),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: categories.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernBottomNav(CartProvider cart) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
      child: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppTheme.primaryGreen,
        unselectedItemColor: Colors.grey[400],
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
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
          const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded, size: 28), label: 'طلباتي'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_rounded, size: 28), label: 'حسابي'),
        ],
        onTap: (index) {
          // توجيه صحيح بناءً على طلبك
          if (index == 1) Navigator.pushNamed(context, '/cart');
          if (index == 2) Navigator.pushNamed(context, '/orders');
          if (index == 3) Navigator.pushNamed(context, '/profile');
        },
      ),
    );
  }
}

