// المسار: lib/widgets/home_content.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:my_test_app/screens/buyer/trader_offers_screen.dart'; 

final FirebaseFirestore _db = FirebaseFirestore.instance;

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _banners = [];
  List<Map<String, dynamic>> _recentProducts = [];

  bool _isLoading = true;
  int _currentBannerIndex = 0;
  late PageController _bannerController;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController(initialPage: 0);
    _loadAllData();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  // --- جلب البيانات ---
  Future<void> _loadCategories() async {
    try {
      final q = await _db.collection('mainCategory')
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false)
          .get();

      final List<Map<String, dynamic>> loadedCategories = q.docs.map((doc) => {
        'id': doc.id,
        'name': doc['name'] ?? '',
        'imageUrl': doc['imageUrl'] ?? '',
      }).toList();

      if (mounted) setState(() => _categories = loadedCategories);
    } catch (e) {
      debugPrint('Error Categories: $e');
    }
  }

  Future<void> _loadRetailerBanners() async {
    try {
      final q = await _db.collection('retailerBanners')
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false)
          .get();

      final List<Map<String, dynamic>> loadedBanners = q.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'linkType': data['linkType'] as String? ?? 'NONE',
          'targetId': data['targetId'] as String? ?? '',
        };
      }).toList();

      if (mounted) setState(() => _banners = loadedBanners);
    } catch (e) {
      debugPrint('Error Banners: $e');
    }
  }

  Future<void> _loadRecentlyAddedProducts() async {
    try {
      final q = await _db.collection('products')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final List<Map<String, dynamic>> loadedProducts = q.docs.map((doc) {
        final data = doc.data();
        final List<dynamic>? urls = data['imageUrls'] as List<dynamic>?;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'منتج',
          'imageUrl': (urls != null && urls.isNotEmpty) ? urls.first as String : '',
          'subId': data['subId'] ?? '',
          'mainId': data['mainId'] ?? '',
        };
      }).toList();

      if (mounted) setState(() => _recentProducts = loadedProducts);
    } catch (e) {
      debugPrint('Error Products: $e');
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([_loadCategories(), _loadRetailerBanners(), _loadRecentlyAddedProducts()]);
    if (mounted) {
      setState(() => _isLoading = false);
      _startBannerAutoSlide();
    }
  }

  void _startBannerAutoSlide() {
    _bannerTimer?.cancel();
    if (_banners.length > 1) {
      _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!mounted || _banners.isEmpty) return;
        int nextPage = (_currentBannerIndex + 1) % _banners.length;
        _bannerController.animateToPage(nextPage, duration: const Duration(milliseconds: 700), curve: Curves.easeOut);
      });
    }
  }

  // 🎯 إصلاح دالة الضغط لتطابق تعريفات main.dart تماماً
  void _handleBannerClick(String? linkType, String? targetId) {
    if (targetId == null || targetId.isEmpty || linkType == null) return;
    final type = linkType.toUpperCase();

    if (type == 'EXTERNAL' && targetId.startsWith('http')) {
      // منطق الروابط الخارجية
    } 
    else if (type == 'PRODUCT') {
      Navigator.of(context).pushNamed('/productDetails', arguments: {'productId': targetId});
    } 
    else if (type == 'CATEGORY') {
      // يوجه لصفحة الأقسام الفرعية كما هو معرف في main.dart السطر 244
      Navigator.of(context).pushNamed('/category', arguments: targetId);
    } 
    else if (type == 'SUB_CATEGORY') {
      // يوجه لصفحة المنتجات مباشرة كما هو معرف في main.dart السطر 247
      Navigator.of(context).pushNamed('/products', arguments: {'subId': targetId, 'mainId': ''});
    }
    else if (type == 'RETAILER') {
      Navigator.of(context).pushNamed(TraderOffersScreen.routeName, arguments: targetId);
    }
  }

  // 🎯 تعديل حجم الأيقونة وتأقلم الصورة
  Widget _buildCategoryCard(Map<String, dynamic> data) {
    const double size = 65.0; // حجم محسّن
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed('/category', arguments: data['id']),
      child: Column(
        children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: ClipOval(
              child: data['imageUrl'].isNotEmpty 
                ? Image.network(data['imageUrl'], fit: BoxFit.cover) // BoxFit.cover يضمن التأقلم
                : const Icon(Icons.category, size: 30),
            ),
          ),
          const SizedBox(height: 8),
          Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Tajawal'), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildBannerSlider() {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (v) => setState(() => _currentBannerIndex = v),
            itemCount: _banners.length,
            itemBuilder: (context, index) => InkWell(
              onTap: () => _handleBannerClick(_banners[index]['linkType'], _banners[index]['targetId']),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(_banners[index]['imageUrl'], fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 15),
          _buildBannerSlider(),
          const SizedBox(height: 25),
          const Text('الأقسام الرئيسية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.9),
            itemBuilder: (context, index) => _buildCategoryCard(_categories[index]),
          ),
          if (_recentProducts.isNotEmpty) ...[
             const SizedBox(height: 20),
             const Padding(padding: EdgeInsets.only(right: 15), child: Align(alignment: Alignment.centerRight, child: Text('أضيف حديثاً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
             SizedBox(height: 180, child: ListView.builder(scrollDirection: Axis.horizontal, reverse: true, itemCount: _recentProducts.length, itemBuilder: (context, index) {
               final p = _recentProducts[index];
               return InkWell(
                 onTap: () => Navigator.of(context).pushNamed('/products', arguments: {'subId': p['subId'], 'mainId': p['mainId']}),
                 child: Container(width: 130, margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: Column(children: [Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(10)), child: Image.network(p['imageUrl'], fit: BoxFit.cover))), Padding(padding: const EdgeInsets.all(4), child: Text(p['name'], maxLines: 1, overflow: TextOverflow.ellipsis))])),
               );
             })),
          ]
        ],
      ),
    );
  }
}
