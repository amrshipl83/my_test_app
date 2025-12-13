// lib/screens/consumer/MarketplaceHomeScreen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// استيراد الخدمات والنماذج
import 'package:my_test_app/services/marketplace_data_service.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/models/banner_model.dart'; // 💡 هذا الاستيراد يجب أن يكون موجوداً
import 'package:my_test_app/providers/theme_notifier.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';

// 🛑 تم تعليق هذا الاستيراد مؤقتاً لتجاوز خطأ 'No such file or directory'
// import 'package:my_test_app/screens/consumer/category_details_screen.dart';

class MarketplaceHomeScreen extends StatefulWidget {
  static const routeName = '/marketplaceHome';

  // المتجر الحالي يجب أن يُمرر إما عبر Constructor أو يُجلب من Provider
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MarketplaceDataService _dataService = MarketplaceDataService();

  late Future<List<BannerModel>> _bannersFuture;
  late Future<List<CategoryModel>> _categoriesFuture;

  // لتقليد منطق الـ Auto Slide
  late PageController _bannerPageController;
  int _currentBannerIndex = 0;
  List<BannerModel> _loadedBanners = [];

  bool _isAutoSlideActive = true;

  @override
  void initState() {
    super.initState();
    // بدء جلب البيانات عند التهيئة
    _bannersFuture = _dataService.fetchBanners(widget.currentStoreId);
    _categoriesFuture = _dataService.fetchCategoriesByOffers(widget.currentStoreId);

    _bannerPageController = PageController();

    // بدء الـ Auto Slide بعد فترة قصيرة
    _bannersFuture.then((banners) {
      if (banners.isNotEmpty) {
        setState(() {
          _loadedBanners = banners;
          _startAutoSlide();
        });
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
          setState(() {
            _currentBannerIndex = nextPage;
          });
          _startAutoSlide();
        });
      });
    }
  }

  void _stopAutoSlide() {
    _isAutoSlideActive = false;
  }

  void _resumeAutoSlide() {
    _isAutoSlideActive = true;
    _startAutoSlide();
  }

  @override
  void dispose() {
    _stopAutoSlide(); // إيقاف التكرار عند التخلص من الودجت

    _bannerPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 💡 استخدام Providers
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    final buyerDataProvider = Provider.of<BuyerDataProvider>(context);

    // 🟢 [التصحيح]: استبدال userLoggedInName و userId بالأسماء الصحيحة (userName و currentUserId)
    final welcomeName = buyerDataProvider.userName ?? buyerDataProvider.currentUserId ?? 'مستخدم';
    final welcomeMessage = 'أهلاً بك يا $welcomeName';
    // تقليد cart count
    final cartCount = 5; // يمكن استخدام Provider/Bloc/Riverpod لقيمة حقيقية

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,

        // --- 1. الشريط الجانبي (Sidebar) ---
        drawer: _buildSidebar(context, themeNotifier),


        body: SafeArea(
          child: Column(
            children: [
              // --- 2. الرأس العلوي (Top Header) ---
              _buildTopHeader(context, themeNotifier, welcomeMessage),

              // --- 3. المحتوى الرئيسي القابل للتمرير ---
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // 3.1 قسم البانرات
                      _buildBannerSlider(),

                      // 3.2 قسم الأقسام الرئيسية
                      _buildCategoriesGrid(),
                      const SizedBox(height: 80), // مسافة لشريط التنقل السفلي
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // --- 4. شريط التنقل السفلي (Mobile Nav) ---
        bottomNavigationBar: _buildMobileNav(context, cartCount),
      ),
    );
  }

  // --- بناء الدوال الفرعية للواجهة ---

  Widget _buildTopHeader(BuildContext context, ThemeNotifier themeNotifier, String welcomeMessage) {
    // تقليد لـ .top-header في HTML
    final headerColor = themeNotifier.isDarkMode
        ? const LinearGradient(colors: [Color(0xFF16213e), Color(0xFF0f3460)])
        : const LinearGradient(colors: [Color(0xFF2c3e50), Color(0xFF4a6491)]);

    return Container(
      padding: const EdgeInsets.only(top: 50, bottom: 15, left: 15, right: 15),
      decoration: BoxDecoration(
        gradient: headerColor,
      ),
      child: Column(
        children: [
          // Header Actions (Menu Toggle & Theme Toggle)
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Theme Toggle
                InkWell(
                  onTap: themeNotifier.toggleTheme,
                  child: Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: Icon(
                      themeNotifier.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                // Menu Toggle (يظهر فقط على الشاشات الصغيرة)
                if (MediaQuery.of(context).size.width < 768)
                  InkWell(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: const Padding(
                      padding: EdgeInsets.all(5.0),
                      child: Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Logo Section
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  FontAwesomeIcons.store,
                  color: Color(0xFF4CAF50),
                  size: 28,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'أسواق أكسب',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Welcome Message
          Text(
            welcomeMessage,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, ThemeNotifier themeNotifier) {
    // بناء الشريط الجانبي (Drawer)
    return Drawer(
      child: Container(
        color: Theme.of(context).cardColor, // تقليد var(--sidebar-bg)
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: themeNotifier.isDarkMode ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      FontAwesomeIcons.store,
                      color: themeNotifier.isDarkMode ? const Color(0xFFbb86fc) : const Color(0xFF4CAF50),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'أسواق أكسب',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                ],
              ),
            ),

            // Navigation
            ListTile(
              leading: const Icon(FontAwesomeIcons.storeAlt),
              title: const Text('التجار'),
              onTap: () {
                Navigator.of(context).pop();
                // توجيه إلى شاشة التجار (analogous to store_details.html)
              },
            ),
            ListTile(
              leading: const Icon(FontAwesomeIcons.user),
              title: const Text('حسابي'),
              onTap: () {
                Navigator.of(context).pop();
                // توجيه إلى شاشة حسابي (analogous to my_details.html)
              },
            ),
            ListTile(
              leading: const Icon(FontAwesomeIcons.infoCircle),
              title: const Text('من نحن'),
              onTap: () {
                Navigator.of(context).pop();
                // توجيه إلى شاشة من نحن (analogous to about.html)
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(FontAwesomeIcons.fileContract),
              title: const Text('الخصوصية والاستخدام'),
              onTap: () {
                Navigator.of(context).pop();
                // توجيه إلى شاشة الخصوصية (analogous to privacy.html)
              },
            ),

            const Spacer(),
            // Footer & Logout
            Container(
              width: double.infinity,
              color: Colors.red[700],
              child: TextButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  // تنفيذ منطق تسجيل الخروج
                  // مثال: Navigator.of(context).pushReplacementNamed('/login');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل الخروج (Simulation)')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerSlider() {
    return FutureBuilder<List<BannerModel>>(
      future: _bannersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // لا يوجد شاشة تحميل للبانرات في HTML، فقط يتم إخفاء القسم
          return const SizedBox.shrink();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // إخفاء القسم بالكامل (display: none)
        }

        _loadedBanners = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'عروض مميزة من المتجر',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),

            // تقليد لـ .banner-slider-container
            Container(
              height: 180, // ارتفاع ثابت للبانر
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  children: [
                    // الـ ViewPager (تقليد لـ .banner-slider-wrapper)
                    NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                          if (notification is ScrollStartNotification) {
                              _stopAutoSlide();
                          } else if (notification is ScrollEndNotification) {
                              _resumeAutoSlide();
                          }
                          return false;
                      },
                      child: PageView.builder(
                        controller: _bannerPageController,
                        itemCount: _loadedBanners.length,

                        onPageChanged: (index) {
                          setState(() {
                              _currentBannerIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final banner = _loadedBanners[index];

                          return GestureDetector(
                            onTap: () {
                              // تنفيذ التوجيه (launch URL)
                            },
                            child: Image.network(
                              banner.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(child: Icon(Icons.broken_image, size: 50)),
                            ),
                          );
                        },
                      ),
                    ),

                    // Dots Indicator (تقليد لـ .banner-dots)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _loadedBanners.asMap().entries.map((entry) {
                          int index = entry.key;
                          return GestureDetector(
                            onTap: () {
                              _bannerPageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              width: 8.0,
                              height: 8.0,
                              margin: const EdgeInsets.symmetric(horizontal: 4.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentBannerIndex == index
                                    ? Theme.of(context).colorScheme.secondary
                                    : Colors.white70,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoriesGrid() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'الأقسام الرئيسية',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),

        FutureBuilder<List<CategoryModel>>(
          future: _categoriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('جاري تحميل الأقسام...'),
                  ],
                ),
              ));
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('حدث خطأ أثناء جلب الأقسام: ${snapshot.error.toString()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final categories = snapshot.data!;

            if (categories.isEmpty) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('لا توجد أقسام نشطة متاحة لهذا المتجر حاليًا.', style: TextStyle(color: Colors.grey)),
              ));
            }

            // تقليد لـ .categories-grid
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // عمودين
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.2, // نسبة الطول للعرض لبطاقة القسم
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return _buildCategoryCard(context, category);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context, CategoryModel category) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          // 🟢 [الربط الجديد]: التوجيه إلى شاشة الأقسام الفرعية للمستهلك
          Navigator.of(context).pushNamed(
            '/subcategories', // المسار الذي تم تعريفه في main.dart
            arguments: {
              'mainId': category.id, // معرف القسم الرئيسي
              'ownerId': widget.currentStoreId, // معرف المتجر الحالي
              'mainCategoryName': category.name, // اسم القسم للعرض في العنوان
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Image.network(
                  category.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                ),
              ),
            ),
            // Name
            Expanded(
              flex: 1,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    category.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNav(BuildContext context, int cartCount) {
    // تقليد لـ .mobile-nav
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 5),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, FontAwesomeIcons.box, 'طلباتي', 'orders.html', isActive: false),
          _buildNavItem(context, FontAwesomeIcons.search, 'البحث', 'find.html', isActive: false),
          _buildNavItem(context, FontAwesomeIcons.shoppingCart, 'السلة', 'cart.html', isActive: false, count: cartCount),
          _buildNavItem(context, FontAwesomeIcons.store, 'التجار', '#', isActive: true), // المتجر الحالي هو النشط
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, String route, {required bool isActive, int count = 0}) {
    final activeColor = Theme.of(context).colorScheme.secondary;
    final inactiveColor = Theme.of(context).textTheme.bodySmall?.color;

    return InkWell(
      onTap: () {
        // تنفيذ التوجيه
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? activeColor : inactiveColor,
              ),
              if (count > 0 && route == 'cart.html')
                Positioned(
                  top: -5,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (route == 'orders.html' && false) // تقليد notification dot
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
