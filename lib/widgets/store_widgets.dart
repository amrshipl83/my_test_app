// lib/widgets/store_widgets.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:my_test_app/services/store_data_service.dart'; // لاستدعاء البيانات والمنطق

// ----------------------------------------------------
// 1. الشريط العلوي (Top Header)
// ----------------------------------------------------
class StoreTopHeader extends StatelessWidget implements PreferredSizeWidget {
  final String fullname;
  final bool isDarkTheme;
  
  const StoreTopHeader({super.key, required this.fullname, required this.isDarkTheme});

  @override
  Size get preferredSize => const Size.fromHeight(150.0);

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      automaticallyImplyLeading: false, // لا يوجد زر رجوع افتراضي
      expandedHeight: 150.0,
      floating: true,
      pinned: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkTheme 
              ? [const Color(0xFF16213e), Colors.green.shade600] // Dark
              : [const Color(0xFF2c3e50), Colors.green.shade600], // Light
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
        ),
        child: FlexibleSpaceBar(
          centerTitle: true,
          titlePadding: const EdgeInsets.only(bottom: 10),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(FontAwesomeIcons.store, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'أسواق أكسب',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const Text(
                'تسوق بسهولة وأمان',
                style: TextStyle(fontSize: 10, color: Colors.white70),
              ),
              Text(
                'أهلاً بك، $fullname!',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        // زر تبديل الثيم
        IconButton(
          icon: FaIcon(isDarkTheme ? FontAwesomeIcons.sun : FontAwesomeIcons.moon),
          onPressed: () {
            // 💡 منطق تغيير الثيم يجب أن يكون في مكان مركزي (مثل Provider/Bloc)
            // بما أننا نستخدم MaterialApp في main.dart، سنفترض وجود طريقة لتغيير themeMode
            // لتبسيط المثال، سنتركه بدون تنفيذ المنطق هنا.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Theme Toggle is Placeholder')),
            );
          },
        ),
      ],
      // 💡 زر فتح الـ Drawer
      leading: Builder(
        builder: (context) {
          final dataService = Provider.of<StoreDataService>(context);
          return Stack(
            children: [
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.bars, color: Colors.white),
                onPressed: () => Scaffold.of(context).openEndDrawer(), // فتح الـ Drawer
              ),
              // نقطة الإشعار (Notification Dot)
              if (dataService.newOrdersCount > 0)
                Positioned(
                  top: 8,
                  left: 8,
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
          );
        },
      ),
      leadingWidth: 60,
    );
  }
}

// ----------------------------------------------------
// 2. شبكة الأقسام (Categories Grid)
// ----------------------------------------------------
class CategoriesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final bool isLoading;
  final String? errorMessage;

  const CategoriesGrid({
    super.key,
    required this.categories,
    required this.isLoading,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('جاري تحميل الأقسام...'),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(errorMessage!),
        ),
      );
    }

    if (categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('لا توجد أقسام متاحة حاليًا'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 عمود للموبايل
          childAspectRatio: 0.9,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return CategoryCard(category: category);
        },
      ),
    );
  }
}

// بطاقة القسم المفردة
class CategoryCard extends StatelessWidget {
  final Map<String, dynamic> category;
  const CategoryCard({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // التوجيه إلى شاشة القسم
        Navigator.of(context).pushNamed('/category', arguments: {'categoryId': category['id']});
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Image.network(
                  category['imageUrl'] ?? 'https://via.placeholder.com/150/0f3460/f0f0f0?text=No Image',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null));
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(child: FaIcon(FontAwesomeIcons.image, size: 50, color: Colors.grey)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                category['name'] ?? 'قسم غير مسمى',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 3. قسم البانر المتحرك (Banner Slider)
// ----------------------------------------------------
class BannerSliderSection extends StatelessWidget {
  const BannerSliderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<StoreDataService>(context);

    if (dataService.banners.isEmpty) {
      return const SizedBox.shrink(); // إخفاء القسم إذا لم يكن هناك بانرات
    }

    return Padding(
      padding: const EdgeInsets.only(top: 30.0, bottom: 20.0, left: 15.0, right: 15.0),
      child: Column(
        children: [
          StoreSectionTitle(title: 'عروض مميزة', icon: FontAwesomeIcons.bullhorn),
          const SizedBox(height: 10),
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: PageView.builder(
                itemCount: dataService.banners.length,
                onPageChanged: dataService.setCurrentBannerIndex,
                itemBuilder: (context, index) {
                  final banner = dataService.banners[index];
                  return Image.network(
                    banner['imageUrl'] ?? 'https://via.placeholder.com/800x180/0f3460/f0f0f0?text=No Image',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Text('خطأ في تحميل البانر')),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          // مؤشرات التنقل (Dots)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              dataService.banners.length,
              (index) => DotIndicator(
                isActive: index == dataService.currentBannerIndex,
                onTap: () {
                  // هنا نحتاج إلى متحكم PageController للـ PageView
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DotIndicator extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const DotIndicator({super.key, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.grey.shade400,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ----------------------------------------------------
// 4. عناصر الشريط الجانبي (Sidebar Components)
// ----------------------------------------------------

class SidebarHeaderWidget extends StatelessWidget {
  const SidebarHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'أسواق أكسب',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(width: 10),
          FaIcon(
            FontAwesomeIcons.store,
            size: 32,
            color: Colors.green.shade600,
          ),
        ],
      ),
    );
  }
}

class SidebarItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final int count;

  const SidebarItem({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, textAlign: TextAlign.right),
      trailing: FaIcon(icon, size: 20),
      leading: count > 0
          ? CircleAvatar(
              radius: 10,
              backgroundColor: Colors.red,
              child: Text(
                count.toString(),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}

class SocialLinksWidget extends StatelessWidget {
  const SocialLinksWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.whatsapp),
            onPressed: () {
              // فتح رابط الواتساب
              // await launchUrl(Uri.parse('https://wa.me/201021070462'));
            },
            color: Colors.green,
            iconSize: 30,
          ),
          const SizedBox(width: 20),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.facebookF),
            onPressed: () {
              // فتح رابط الفيسبوك
              // await launchUrl(Uri.parse('https://www.facebook.com/share/199za9SBSE/'));
            },
            color: Colors.blue.shade800,
            iconSize: 30,
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 5. شريط التنقل السفلي (Mobile Nav)
// ----------------------------------------------------
class StoreMobileNav extends StatelessWidget {
  const StoreMobileNav({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<StoreDataService>(context);
    // 💡 افتراض: استخدام RouteName لمعرفة أي زر هو النشط حاليًا (سيبدو معقدًا هنا، سنفترض النشاط مؤقتاً)
    const currentRoute = '/buyer-home';
    final cartCount = dataService.cartCount;
    final hasOrderChanges = dataService.hasOrderChanges;

    return BottomAppBar(
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _MobileNavItem(
            title: 'مشترياتى',
            icon: FontAwesomeIcons.box,
            route: '/my-orders',
            isActive: currentRoute == '/my-orders',
            showDot: hasOrderChanges, // نقطة إشعار تغيير حالة الطلب
            onTap: () => Navigator.of(context).pushNamed('/my-orders'),
          ),
          _MobileNavItem(
            title: 'البحث',
            icon: FontAwesomeIcons.search,
            route: '/search',
            isActive: currentRoute == '/search',
            onTap: () => Navigator.of(context).pushNamed('/search-merchants'), // مسار Find.html
          ),
          _MobileCartItem(
            count: cartCount,
            onTap: () => Navigator.of(context).pushNamed('/cart'),
          ),
          _MobileNavItem(
            title: 'التجار',
            icon: FontAwesomeIcons.store,
            route: '/traders',
            isActive: currentRoute == '/traders',
            onTap: () => Navigator.of(context).pushNamed('/search-merchants'), // مسار Traders.html
          ),
        ],
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;
  final bool isActive;
  final bool showDot;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.title,
    required this.icon,
    required this.route,
    this.isActive = false,
    this.showDot = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.green.shade600 : Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              children: [
                FaIcon(icon, size: 20, color: color),
                if (showDot)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileCartItem extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _MobileCartItem({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              children: <Widget>[
                FaIcon(FontAwesomeIcons.shoppingCart, size: 20, color: Colors.grey.shade600),
                if (count > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'السلة',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 6. عنوان القسم المشترك
// ----------------------------------------------------
class StoreSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const StoreSectionTitle({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}
