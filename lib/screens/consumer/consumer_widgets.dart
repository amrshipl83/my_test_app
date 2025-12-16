// lib/screens/consumer/consumer_widgets.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_test_app/theme/app_theme.dart';
import 'consumer_data_models.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';
import 'package:my_test_app/screens/consumer/points_loyalty_screen.dart';

// 1. شريط التنقل العلوي المخصص (Top Bar)
class ConsumerCustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String userName;
  final int userPoints;
  final VoidCallback onMenuPressed;

  const ConsumerCustomAppBar({
    super.key,
    required this.userName,
    required this.userPoints,
    required this.onMenuPressed,
  });

  static const Color accent = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    final Color appPrimary = AppTheme.primaryGreen;
    final Color appAccent = accent;
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('consumers')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // استخدام القيم القادمة من Firestore أو القيم الافتراضية
        String displayUserName = userName;
        int displayPoints = userPoints;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayUserName = data['fullName'] ?? data['name'] ?? userName;
          displayPoints = data['points'] ?? data['loyaltyPoints'] ?? 0;
        }

        return AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          toolbarHeight: 55,
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 2,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    InkWell(
                      // 🎯 تم التأكد من ربطها بفتح الـ Sidebar
                      onTap: onMenuPressed, 
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: appPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        height: 40,
                        // استخدام أيقونة Bars واحدة كما طلبت
                        child: Icon(FontAwesomeIcons.bars, size: 18, color: appPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('مرحباً بعودتك،',
                            style: TextStyle(fontSize: 10, color: Color(0xFF6C757D), height: 1.2)),
                        Text(displayUserName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2)),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      // 🎯 تصحيح مسار أيقونة النقاط
                      onTap: () => Navigator.of(context).pushNamed(PointsLoyaltyScreen.routeName),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: appAccent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: appAccent.withOpacity(0.5), blurRadius: 5),
                          ],
                        ),
                        height: 35,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(FontAwesomeIcons.star, size: 14, color: Colors.black),
                            const SizedBox(width: 5),
                            Text(displayPoints.toString(),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(55);
}

// 3. شريط البحث ثلاثي الأبعاد
class ConsumerSearchBar extends StatelessWidget {
  const ConsumerSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final Color appPrimary = AppTheme.primaryGreen;
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(ConsumerStoreSearchScreen.routeName);
      },
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(FontAwesomeIcons.mapMarkerAlt, size: 18, color: appPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'البحث عن أقرب سوبر ماركت/مطعم...',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.secondaryTextColor),
          ],
        ),
      ),
    );
  }
}

// 4. عنوان القسم
class ConsumerSectionTitle extends StatelessWidget {
  final String title;
  const ConsumerSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final Color appPrimary = AppTheme.primaryGreen;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            color: appPrimary,
            margin: const EdgeInsets.only(left: 10),
          ),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// 5. بانر الأقسام
class ConsumerCategoriesBanner extends StatelessWidget {
  final List<ConsumerCategory> categories;
  const ConsumerCategoriesBanner({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemBuilder: (context, index) {
            final category = categories[index];
            return Padding(
              padding: EdgeInsets.only(left: index < categories.length - 1 ? 20 : 0),
              child: ConsumerCategoryItem(category: category),
            );
          },
        ),
      ),
    );
  }
}

class ConsumerCategoryItem extends StatelessWidget {
  final ConsumerCategory category;
  const ConsumerCategoryItem({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final Color appPrimary = AppTheme.primaryGreen;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/category', arguments: category.id);
      },
      child: SizedBox(
        width: 85,
        child: Column(
          children: [
            Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: appPrimary, width: 3),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: category.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (context, url, error) => Icon(FontAwesomeIcons.shoppingBasket, color: appPrimary),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// 6. بانر العروض الترويجية
class ConsumerPromoBanners extends StatelessWidget {
  final List<ConsumerBanner> banners;
  const ConsumerPromoBanners({super.key, required this.banners});

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: SizedBox(
        height: 180,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: banners.length,
          itemBuilder: (context, index) {
            final banner = banners[index];
            return Padding(
              padding: EdgeInsets.only(left: index < banners.length - 1 ? 10 : 0),
              child: GestureDetector(
                onTap: () => print('Open Banner Link: ${banner.link}'),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: banner.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Center(child: Text('خطأ في تحميل الصورة')),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// 7. شريط التنقل السفلي (Footer Nav)
class ConsumerFooterNav extends StatelessWidget {
  final int cartCount;
  final int activeIndex;
  const ConsumerFooterNav({super.key, required this.cartCount, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final List<_ConsumerNavItem> items = [
      const _ConsumerNavItem(icon: FontAwesomeIcons.store, label: 'المتجر', route: '/consumerHome'),
      const _ConsumerNavItem(icon: FontAwesomeIcons.clipboardList, label: 'الطلبات', route: '/consumer-purchases'),
      const _ConsumerNavItem(icon: FontAwesomeIcons.shoppingCart, label: 'السلة', route: '/cart'),
      const _ConsumerNavItem(icon: FontAwesomeIcons.user, label: 'حسابي', route: '/myDetails'),
    ];

    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isActive = index == activeIndex;
          return Expanded(
            child: ConsumerFooterNavItem(
              item: item,
              isActive: isActive,
              cartCount: index == 2 ? cartCount : 0,
              onTap: () => Navigator.of(context).pushNamed(item.route),
            ),
          );
        }),
      ),
    );
  }
}

class ConsumerFooterNavItem extends StatelessWidget {
  final _ConsumerNavItem item;
  final bool isActive;
  final int cartCount;
  final VoidCallback onTap;

  const ConsumerFooterNavItem({
    super.key,
    required this.item,
    required this.isActive,
    required this.cartCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primaryGreen : AppTheme.secondaryTextColor;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Icon(item.icon, size: 24, color: color),
              if (cartCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Color(0xFFdc3545), shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text('$cartCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                )
            ],
          ),
          const SizedBox(height: 2),
          Text(item.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _ConsumerNavItem {
  final IconData icon;
  final String label;
  final String route;
  const _ConsumerNavItem({required this.icon, required this.label, required this.route});
}

// 8. القائمة الجانبية (Sidebar)
class ConsumerSideMenu extends StatelessWidget {
  const ConsumerSideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final Color appPrimary = AppTheme.primaryGreen;
    return Drawer(
      width: 300,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(left: BorderSide(color: AppTheme.borderColor, width: 2)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('قائمة المستخدم', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: appPrimary)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.5)),
                      ),
                      child: Center(child: Icon(FontAwesomeIcons.times, size: 20, color: AppTheme.secondaryTextColor)),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppTheme.borderColor, thickness: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const _ConsumerSidebarItem(icon: FontAwesomeIcons.home, label: 'الصفحة الرئيسية', route: '/consumerHome', isActive: true),
                  const _ConsumerSidebarItem(icon: FontAwesomeIcons.shoppingBasket, label: 'سلة التسوق', route: '/cart'),
                  const _ConsumerSidebarItem(icon: FontAwesomeIcons.search, label: 'بحث عن منتجات', route: '/search'),
                  const _ConsumerSidebarItem(icon: FontAwesomeIcons.history, label: 'طلباتي السابقة', route: '/consumer-purchases'),
                  // 🎯 تم تحديث مسار النقاط لمسار الشاشة الجديد
                  const _ConsumerSidebarItem(icon: FontAwesomeIcons.gift, label: 'نقاط الولاء والمكافآت', route: PointsLoyaltyScreen.routeName),
                  const _ConsumerSidebarItem(icon: FontAwesomeIcons.userCircle, label: 'ملفي الشخصي', route: '/myDetails'),
                  const _ConsumerSidebarItem(icon: FontAwesomeIcons.infoCircle, label: 'الإعدادات والدعم', route: '/about'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: _ConsumerSidebarItem(
                icon: FontAwesomeIcons.signOutAlt,
                label: 'تسجيل الخروج',
                isLogout: true,
                onTap: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsumerSidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isLogout;
  final String route;
  final VoidCallback? onTap;

  const _ConsumerSidebarItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.isLogout = false,
    this.route = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColor = isLogout ? const Color(0xFF721c24) : Theme.of(context).textTheme.bodyLarge?.color;
    final defaultBg = isLogout ? const Color(0xFFf8d7da) : Theme.of(context).colorScheme.surface;
    final iconColor = isLogout ? const Color(0xFFdc3545) : AppTheme.primaryGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: defaultBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap ?? () => Navigator.of(context).pushNamed(route),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: isLogout ? Border.all(color: const Color(0xFFf5c6cb)) : null,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isLogout ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: iconColor),
                const SizedBox(width: 15),
                Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: defaultColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
