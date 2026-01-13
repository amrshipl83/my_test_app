import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'consumer_data_models.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';
import 'package:my_test_app/screens/consumer/points_loyalty_screen.dart';

// 1. القائمة الجانبية (Drawer) - الاسم والخصوصية والخروج فقط
class ConsumerSideMenu extends StatelessWidget {
  const ConsumerSideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Column(
        children: [
          // جزء الهيدر - يسحب الاسم من كولكشن consumers
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('consumers').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              String name = "مستخدِم كسبان";
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                name = data['fullname'] ?? "مستخدِم كسبان";
              }
              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF43A047)),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person_rounded, size: 50, color: Color(0xFF43A047)),
                ),
                accountName: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                accountEmail: Text(user?.email ?? ""),
              );
            },
          ),

          // سياسة الخصوصية
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF43A047), size: 28),
            title: const Text('سياسة الخصوصية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onTap: () async {
              final url = Uri.parse('https://amrshipl83.github.io/aksabprivce/');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          
          const Divider(),

          // تسجيل الخروج
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red, size: 28),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}

// 2. شريط التنقل العلوي (AppBar) - متوافق مع صفحة الـ Home
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

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFF43A047),
      elevation: 2,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // زر فتح المنيو
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 30),
            onPressed: onMenuPressed,
          ),
          
          // اسم المستخدم
          Expanded(
            child: Text(
              userName,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),

          // كبسولة النقاط
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(PointsLoyaltyScreen.routeName),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 4),
                  Text('$userPoints', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(65);
}

// 3. بقية الـ Widgets الأساسية المطلوبة لنجاح الـ Build
class ConsumerSectionTitle extends StatelessWidget {
  final String title;
  const ConsumerSectionTitle({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }
}

class ConsumerFooterNav extends StatelessWidget {
  final int cartCount;
  final int activeIndex;
  const ConsumerFooterNav({super.key, required this.cartCount, required this.activeIndex});
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: activeIndex == -1 ? 0 : activeIndex,
      selectedItemColor: const Color(0xFF43A047),
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.store), label: 'المتجر'),
        const BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'طلباتي'),
        const BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'السلة'),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
      ],
      onTap: (index) {
        final routes = ['/consumerhome', '/consumer-purchases', '/cart', '/myDetails'];
        Navigator.pushNamed(context, routes[index]);
      },
    );
  }
}

class ConsumerCategoriesBanner extends StatelessWidget {
  final List<ConsumerCategory> categories;
  const ConsumerCategoriesBanner({super.key, required this.categories});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              CircleAvatar(radius: 35, backgroundImage: CachedNetworkImageProvider(categories[index].imageUrl)),
              Text(categories[index].name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class ConsumerPromoBanners extends StatelessWidget {
  final List<ConsumerBanner> banners;
  final double height;
  const ConsumerPromoBanners({super.key, required this.banners, this.height = 200});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: PageView.builder(
        itemCount: banners.length,
        itemBuilder: (context, index) => Image.network(banners[index].imageUrl, fit: BoxFit.cover),
      ),
    );
  }
}

class ConsumerSearchBar extends StatelessWidget {
  const ConsumerSearchBar({super.key});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.pushNamed(context, ConsumerStoreSearchScreen.routeName),
      leading: const Icon(Icons.radar, color: Color(0xFF43A047)),
      title: const Text('رادار المحلات القريبة', style: TextStyle(fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}
