// lib/screens/consumer/MarketplaceHomeScreen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sizer/sizer.dart';

// استيراد الخدمات والنماذج
import 'package:my_test_app/services/marketplace_data_service.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/models/banner_model.dart';
import 'package:my_test_app/providers/theme_notifier.dart';
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
  List<BannerModel> _loadedBanners = [];
  bool _isAutoSlideActive = true;

  @override
  void initState() {
    super.initState();
    _bannersFuture = _dataService.fetchBanners(widget.currentStoreId);
    _categoriesFuture = _dataService.fetchCategoriesByOffers(widget.currentStoreId);
    _bannerPageController = PageController();

    _bannersFuture.then((banners) {
      if (banners.isNotEmpty) {
        setState(() => _loadedBanners = banners);
        _startAutoSlide();
      }
    });
  }

  void _startAutoSlide() {
    if (_loadedBanners.length > 1 && _isAutoSlideActive) {
      Future.delayed(const Duration(seconds: 5)).then((_) {
        if (!mounted) return;
        int nextPage = (_currentBannerIndex + 1) % _loadedBanners.length;
        _bannerPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        ).then((_) {
          if (mounted) {
            setState(() => _currentBannerIndex = nextPage);
            _startAutoSlide();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _isAutoSlideActive = false;
    _bannerPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyerProvider = Provider.of<BuyerDataProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final welcomeName = buyerProvider.userName ?? 'مستخدم';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildModernAppBar(welcomeName),
        body: CustomScrollView(
          slivers: [
            // 1. قسم البانرات (Slider)
            SliverToBoxAdapter(child: _buildBannerSlider()),

            // 2. عنوان "الأقسام الرئيسية"
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 1.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("الأقسام الرئيسية", 
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.black87)),
                    TextButton(onPressed: () {}, child: const Text("عرض الكل")),
                  ],
                ),
              ),
            ),

            // 3. شبكة الأقسام
            _buildCategoriesGrid(),
            
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(cartProvider),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(String name) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 10.h,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
            child: Icon(Icons.person_outline, color: AppTheme.primaryGreen),
          ),
          SizedBox(width: 3.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("مرحباً بك، $name", style: TextStyle(fontSize: 11.sp, color: Colors.black87, fontWeight: FontWeight.bold)),
              Text(widget.currentStoreName, style: TextStyle(fontSize: 9.sp, color: Colors.grey)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded, color: Colors.black)),
      ],
    );
  }

  Widget _buildBannerSlider() {
    return FutureBuilder<List<BannerModel>>(
      future: _bannersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        
        return Container(
          height: 20.h,
          margin: EdgeInsets.symmetric(vertical: 2.h),
          child: Stack(
            children: [
              PageView.builder(
                controller: _bannerPageController,
                itemCount: snapshot.data!.length,
                onPageChanged: (i) => setState(() => _currentBannerIndex = i),
                itemBuilder: (context, index) {
                  final banner = snapshot.data![index];
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(image: NetworkImage(banner.imageUrl), fit: BoxFit.cover),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                          begin: Alignment.bottomCenter,
                        ),
                      ),
                      padding: EdgeInsets.all(4.w),
                      alignment: Alignment.bottomRight,
                      child: Text("أقوى عروض ${widget.currentStoreName}", 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp)),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 10, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: snapshot.data!.asMap().entries.map((e) => Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentBannerIndex == e.key ? Colors.white : Colors.white54,
                    ),
                  )).toList(),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesGrid() {
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
              childAspectRatio: 0.9,
              crossAxisSpacing: 4.w,
              mainAxisSpacing: 4.w,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cat = categories[index];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).pushNamed('/subcategories', arguments: {
                      'mainId': cat.id,
                      'ownerId': widget.currentStoreId,
                      'mainCategoryName': cat.name,
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Image.network(cat.imageUrl, fit: BoxFit.contain),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 2.h),
                          child: Text(cat.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp)),
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

  Widget _buildBottomNav(CartProvider cart) {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: AppTheme.primaryGreen,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.store_rounded), label: 'المتجر'),
        const BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'البحث'),
        BottomNavigationBarItem(
          icon: Badge(label: Text(cart.itemCount.toString()), child: const Icon(Icons.shopping_cart_outlined)),
          label: 'سلتك',
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'طلباتي'),
      ],
    );
  }
}
