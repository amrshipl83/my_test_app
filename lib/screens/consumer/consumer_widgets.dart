import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart'; // تأكد من وجود مكتبة sizer في pubspec.yaml
import 'consumer_data_models.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';
import 'package:my_test_app/screens/consumer/points_loyalty_screen.dart';

// 1. شريط التنقل العلوي المطور - تصميم فخم بخطوط واضحة
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
    final user = FirebaseAuth.instance.currentUser;
    final Color primaryGreen = const Color(0xFF2E7D32);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('consumers').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        String displayUserName = userName;
        int displayPoints = userPoints;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayUserName = data['fullname'] ?? data['fullName'] ?? userName;
          displayPoints = data['loyaltyPoints'] ?? data['points'] ?? 0;
          if (displayUserName.contains(' ')) {
            displayUserName = displayUserName.split(' ').first; // عرض الاسم الأول فقط
          }
        }

        return AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGreen, const Color(0xFF43A047)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_open_rounded, color: Colors.white, size: 35),
                    onPressed: onMenuPressed,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('مرحباً بك،', style: TextStyle(fontSize: 11.sp, color: Colors.white70)),
                      Text(
                        displayUserName.toUpperCase(),
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.black, color: Colors.white)
                      ),
                    ],
                  ),
                ],
              ),
              // بطاقة النقاط الفاخرة
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed(PointsLoyaltyScreen.routeName),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, size: 22, color: Color(0xFFFFD700)),
                      const SizedBox(width: 6),
                      Text(
                        '$displayPoints',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(85);
}

// 2. القائمة الجانبية الاحترافية - تشمل سياسة الخصوصية ومسح الذاكرة
class ConsumerSideMenu extends StatelessWidget {
  const ConsumerSideMenu({super.key});

  Future<void> _launchPrivacyUrl() async {
    final Uri url = Uri.parse('https://amrshipl83.github.io/aksabprivce/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const Color activeGreen = Color(0xFF2E7D32);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [activeGreen, Color(0xFF66BB6A)]),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 50, color: activeGreen),
            ),
            accountName: Text('مستخدم أكسب', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
            accountEmail: Text(user?.email ?? '', style: TextStyle(fontSize: 11.sp)),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(Icons.home_rounded, 'الرئيسية', () => Navigator.pop(context)),
                _buildDrawerItem(Icons.shopping_bag_rounded, 'طلباتي', () => Navigator.pushNamed(context, '/consumer-purchases')),
                _buildDrawerItem(Icons.stars_rounded, 'نقاط الولاء', () => Navigator.pushNamed(context, PointsLoyaltyScreen.routeName)),
                const Divider(thickness: 1, indent: 20, endIndent: 20),
                
                // زر سياسة الخصوصية المرتبط برابط GitHub
                _buildDrawerItem(Icons.privacy_tip_rounded, 'سياسة الخصوصية', () {
                  Navigator.pop(context);
                  _launchPrivacyUrl();
                }, color: Colors.blueGrey),

                const Divider(thickness: 1, indent: 20, endIndent: 20),
                
                // زر تسجيل الخروج الآمن (مسح الذاكرة)
                _buildDrawerItem(Icons.logout_rounded, 'تسجيل الخروج', () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear(); // مسح الذاكرة المؤقتة تماماً
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }
                }, color: Colors.redAccent),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {Color color = Colors.black87}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 28),
      title: Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: color)),
      onTap: onTap,
    );
  }
}

// 3. عنوان القسم - خط كبير وواضح
class ConsumerSectionTitle extends StatelessWidget {
  final String title;
  const ConsumerSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Container(width: 6, height: 28, decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 15),
          Text(title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.black)),
        ],
      ),
    );
  }
}

// 4. بانر الأقسام المطور
class ConsumerCategoriesBanner extends StatelessWidget {
  final List<ConsumerCategory> categories;
  const ConsumerCategoriesBanner({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Container(
            width: 100,
            padding: const EdgeInsets.all(5),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF43A047), width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white,
                    child: ClipOval(child: CachedNetworkImage(imageUrl: cat.imageUrl, fit: BoxFit.cover, width: 76, height: 76)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(cat.name, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 5. شريط التنقل السفلي الاحترافي
class ConsumerFooterNav extends StatelessWidget {
  final int cartCount;
  final int activeIndex;
  const ConsumerFooterNav({super.key, required this.cartCount, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, Icons.home_rounded, 'الرئيسية', 0, '/consumerhome'),
          _buildNavItem(context, Icons.shopping_basket_rounded, 'طلباتي', 1, '/consumer-purchases'),
          _buildNavItem(context, Icons.shopping_cart_rounded, 'السلة', 2, '/cart', count: cartCount),
          _buildNavItem(context, Icons.person_rounded, 'حسابي', 3, '/myDetails'),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, int index, String route, {int count = 0}) {
    final bool isActive = activeIndex == index;
    final Color activeColor = const Color(0xFF2E7D32);

    return InkWell(
      onTap: () => isActive ? null : Navigator.of(context).pushNamed(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: isActive ? activeColor : Colors.grey[400], size: 30),
              if (count > 0)
                Positioned(
                  right: -8, top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? activeColor : Colors.grey, fontSize: 10.sp, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
