import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'consumer_data_models.dart';

// 1. الشريط الجانبي (Side Menu)
class ConsumerSideMenu extends StatelessWidget {
  const ConsumerSideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Column(
        children: [
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
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF43A047), size: 28),
            title: const Text('سياسة الخصوصية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onTap: () async {
              final url = Uri.parse('https://amrshipl83.github.io/aksabprivce/');
              if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red, size: 28),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}

// 2. شريط التنقل السفلي (Footer Nav)
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
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.store), label: 'المتجر'),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'طلباتي'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'السلة'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
      ],
      onTap: (index) {
        final routes = ['/consumerhome', '/consumer-purchases', '/cart', '/myDetails'];
        Navigator.pushNamed(context, routes[index]);
      },
    );
  }
}

// 3. العناوين (Section Titles)
class ConsumerSectionTitle extends StatelessWidget {
  final String title;
  const ConsumerSectionTitle({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// 4. بانر الأقسام (Main Categories)
class ConsumerCategoriesBanner extends StatelessWidget {
  final List<ConsumerCategory> categories;
  const ConsumerCategoriesBanner({super.key, required this.categories});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              CircleAvatar(
                radius: 30, 
                backgroundImage: NetworkImage(categories[index].imageUrl)
              ),
              const SizedBox(height: 5),
              Text(categories[index].name, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// 🎯 تم حذف الكلاس رقم 5 (ConsumerPromoBanners) من هنا 
// وسيتم استبداله في الهوم بـ PromoSliderWidget من ملفه الجديد.
