// المسار: lib/widgets/home_content.dart
// تم تحديث المنطق ليشمل: 1) تفعيل التحريك التلقائي. 2) توحيد مسار الأقسام الرئيسية إلى '/category' ليطابق التعريف في main.dart.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // 💡 استيراد مكتبة Timer

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
  Timer? _bannerTimer; // متغير الـ Timer

  @override
  void initState() {
    super.initState();
    _bannerController = PageController(initialPage: 0);
    _loadAllData();
    _bannerController.addListener(() {
      if (_bannerController.page != null) {
        setState(() {
          _currentBannerIndex = _bannerController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel(); // إلغاء الـ Timer
    _bannerController.dispose();
    super.dispose();
  }

  // --- منطق جلب البيانات من Firestore ---
  Future<void> _loadCategories() async {
    try {
      final q = _db.collection('mainCategory')
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false)
          .get();

      final querySnapshot = await q;
      final List<Map<String, dynamic>> loadedCategories = [];

      querySnapshot.docs.forEach((doc) {
        if (doc.data().containsKey('name') && doc.data().containsKey('imageUrl')) {
          loadedCategories.add({
            'id': doc.id,
            'name': doc['name'],
            'imageUrl': doc['imageUrl'],
          });
        }
      });

      if (mounted) {
        setState(() {
          _categories = loadedCategories;
        });
      }
    } catch (e) {
      print('Firebase Error loading Categories: $e');
    }
  }

  Future<void> _loadRetailerBanners() async {
    try {
      final q = _db.collection('retailerBanners')
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false)
          .get();

      final querySnapshot = await q;
      final List<Map<String, dynamic>> loadedBanners = [];

      querySnapshot.docs.forEach((doc) {
        if (doc.data().containsKey('name') && doc.data().containsKey('imageUrl')) {
            loadedBanners.add({
                'id': doc.id,
                'name': doc['name'],
                'imageUrl': doc['imageUrl'],
                'linkType': doc.data()['linkType'] as String? ?? 'NONE',
                'targetId': doc.data()['targetId'] as String? ?? '',
            });
          }
      });

      if (mounted) {
        setState(() {
          _banners = loadedBanners;
        });
      }
    } catch (e) {
      print('Firebase Error loading Banners: $e');
    }
  }

  Future<void> _loadRecentlyAddedProducts() async {
    try {
      final q = _db.collection('products')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final querySnapshot = await q;
      final List<Map<String, dynamic>> loadedProducts = [];

      querySnapshot.docs.forEach((doc) {
         final data = doc.data();

         final List<dynamic>? urls = data['imageUrls'] as List<dynamic>?;
         final String firstImageUrl = (urls != null && urls.isNotEmpty)
                                       ? urls.first as String : '';

         loadedProducts.add({
            'id': doc.id,
            'name': data['name'] as String? ?? 'منتج',
            'imageUrl': firstImageUrl,
            'subId': data['subId'] as String? ?? '',
         });
      });

      if (mounted) {
        setState(() {
          _recentProducts = loadedProducts;
        });
      }
    } catch (e) {
      print('Firebase Error loading recent products: $e');
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadCategories(),
      _loadRetailerBanners(),
      _loadRecentlyAddedProducts(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _startBannerAutoSlide(); // البدء بعد تحميل البيانات
    }
  }

  // 💡 الدالة المسؤولة عن التحريك التلقائي
  void _startBannerAutoSlide() {
    _bannerTimer?.cancel(); // إلغاء أي مؤقت سابق

    if (_banners.length > 1) {
      _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!mounted || _banners.isEmpty) {
          timer.cancel();
          return;
        }

        int nextPage = (_currentBannerIndex + 1) % _banners.length;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _handleBannerClick(String? linkType, String? targetId) {
    if (targetId == null || targetId.isEmpty || linkType == null) {
      return;
    }

    final type = linkType.toUpperCase();

    if (type == 'EXTERNAL' && targetId.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يتم فتح الرابط الخارجي: $targetId', textDirection: TextDirection.rtl)),
      );
    }
    else if (type == 'PRODUCT') {
      Navigator.of(context).pushNamed(
        '/productDetails',
        arguments: targetId,
        );
    }
    else if (type == 'CATEGORY') {
      // هذا التوجيه يُستخدم للبانرات لفتح قائمة منتجات مباشرة
      Navigator.of(context).pushNamed(
          '/products',
        arguments: {
            'mainId': targetId,
            'subId': '',
        },
      );
    }
    else if (type == 'RETAILER') {
      Navigator.of(context).pushNamed(
          '/retailerDetails',
          arguments: targetId,
      );
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('نوع الرابط غير مدعوم: $linkType', textDirection: TextDirection.rtl)),
      );
      debugPrint('Unsupported link type: $linkType');
    }
  }

  // --- Widgets البناء المُحسَّنة (الأقسام) ---
  Widget _buildCategoryCard(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'قسم';
    final imageUrl = data['imageUrl'] as String? ?? '';

    const double size = 70.0;
    const double iconPadding = 8.0;
    const double totalDiameter = size + iconPadding;

    Widget categoryIconOrImage;

    if (imageUrl.isNotEmpty) {
        categoryIconOrImage = Container(
            width: totalDiameter,
            height: totalDiameter,
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                    ),
                ],
            ),
            child: ClipOval(
                child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: totalDiameter,
                    height: totalDiameter,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildDefaultCircularIcon(size, isPlaceholder: true),
                    loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(child: SizedBox(
                            width: totalDiameter * 0.5, height: totalDiameter * 0.5,
                            child: CircularProgressIndicator(
                                color: const Color(0xFF4CAF50),
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                            ),
                        ));
                    },
                ),
            ),
        );
    } else {
        categoryIconOrImage = _buildDefaultCircularIcon(size);
    }

    return InkWell(
        // 🚀 التصحيح النهائي: استخدام المسار المعرَّف '/category'
        onTap: () {
            // هذا المسار يستخدم ID القسم الرئيسي لفتح شاشة الأقسام الفرعية (BuyerCategoryScreen)
            Navigator.of(context).pushNamed(
                '/category', // ⬅️ المسار المعرَّف في onGenerateRoute بملف main.dart
                arguments: data['id'], // ID القسم الرئيسي
            );
        },
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
                categoryIconOrImage,
                const SizedBox(height: 8),
                Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF2c3e50)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                ),
            ],
        ),
    );
  }

  Widget _buildDefaultCircularIcon(double size, {bool isPlaceholder = false}) {
    const double padding = 8.0;
    final Color borderColor = isPlaceholder ? Colors.grey.shade300 : const Color(0xFF4CAF50);
    final double diameter = size + padding;

    return Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: isPlaceholder ? 1 : 1.5),
            boxShadow: isPlaceholder ? null : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                ),
            ],
        ),
        child: const Icon(Icons.category_rounded, size: 35, color: Color(0xFF2c3e50)),
    );
  }

  Widget _buildBannerSlider() {
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
        children: [
        Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha((255 * 0.12).round()), blurRadius: 10, offset: const Offset(0, 5)),
                ],
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: PageView.builder(
                    controller: _bannerController,
                    itemCount: _banners.length,
                    itemBuilder: (context, index) {
                        final banner = _banners[index];
                        final imageUrl = banner['imageUrl'] as String? ?? 'https://via.placeholder.com/800x140/0f3460/f0f0f0?text=Banner';

                        return InkWell(
                            onTap: () {
                                _handleBannerClick(banner['linkType'] as String?, banner['targetId'] as String?);
                            },
                            child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                    color: const Color(0xFF4CAF50).withAlpha((255 * 0.5).round()),
                                    child: Center(child: Text(banner['name'] ?? 'عرض مميز', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textDirection: TextDirection.rtl)),
                                ),
                            ),
                        );
                    },
                ),
            ),
        ),
        const SizedBox(height: 10),
        // مؤشرات النقاط (Dots Indicator)
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _banners.asMap().entries.map((entry) {
            final index = entry.key;
            return Container(
                width: 8.0, height: 8.0,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentBannerIndex == index ? const Color(0xFF4CAF50) : Colors.grey.shade400,
                ),
            );
            }).toList(),
        ),
        ],
    );
  }

  // 2. 🚀 تحسين تصميم بطاقة "أضيف حديثاً" (Recent Products Card)
  Widget _buildProductCard(Map<String, dynamic> productData) {
    final name = productData['name'] as String? ?? 'منتج';
    final imageUrl = productData['imageUrl'] as String? ?? '';
    final productId = productData['id'] as String? ?? '';
    final subId = productData['subId'] as String? ?? '';

    final List<Color> colors = [
        Colors.blue.shade100,
        Colors.green.shade100,
        Colors.orange.shade100,
        Colors.purple.shade100,
        Colors.red.shade100,
    ];
    final colorIndex = (productId.hashCode % colors.length).abs();
    final color = colors[colorIndex];

    return InkWell(
        onTap: () {
            // 🎯 التوجيه لصفحة المنتجات بالتصفية بـ SubId
            if (subId.isNotEmpty) {
                Navigator.of(context).pushNamed(
                    '/products', // المسار الصحيح الذي يستقبل SubId
                    arguments: {
                        'subId': subId,
                        'mainId': '',
                    },
                );
            } else {
                print('Sub Category ID (subId) is missing for: $name');
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('المنتج غير مرتبط بقسم فرعي.', textDirection: TextDirection.rtl)),
                );
            }
        },
        child: Container(
            width: 150,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha((255 * 0.12).round()),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                    ),
                ],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    SizedBox(
                        height: 120, // ارتفاع ثابت للصورة
                        child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                        color: color,
                                        child: Center(child: Icon(Icons.shopping_bag_rounded, size: 40, color: const Color(0xFF2c3e50).withAlpha((255 * 0.7).round()))),
                                    ),
                                )
                                : Container(
                                    color: color,
                                    child: Center(child: Icon(Icons.shopping_bag_rounded, size: 40, color: const Color(0xFF2c3e50).withAlpha((255 * 0.7).round()))),
                                  ),
                        ),
                    ),
                    Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                                Text(
                                    name,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2c3e50)),
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.rtl,
                                ),
                            ],
                        ),
                    ),
                ],
            ),
        ),
    );
  }

  Widget _buildRecentlyAddedSection() {
    if (_recentProducts.isEmpty) return const SizedBox.shrink();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
            Padding(
                padding: const EdgeInsets.only(right: 15.0, left: 15.0, bottom: 8.0),
                child: Text(
                    'أضيف حديثاً',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50)),
                ),
            ),
            SizedBox(
                height: 200,
                child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    itemCount: _recentProducts.length,
                    itemBuilder: (context, index) {
                        return Padding(
                            padding: EdgeInsets.only(
                                right: index == _recentProducts.length - 1 ? 15 : 0,
                                left: index == 0 ? 15 : 0,
                            ),
                            child: _buildProductCard(_recentProducts[index]),
                        );
                    },
                ),
            ),
        ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
    }

    return SingleChildScrollView(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
                const SizedBox(height: 20),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: _buildBannerSlider(),
                ),
                const SizedBox(height: 30),

                // عنوان الأقسام الرئيسية
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15.0),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(Icons.local_offer_rounded, color: Color(0xFF2c3e50)),
                            SizedBox(width: 8),
                            Text('الأقسام الرئيسية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50))),
                        ],
                    ),
                ),
                const SizedBox(height: 15),

                // شبكة الأقسام (Categories Grid)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _categories.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 15,
                            childAspectRatio: 0.85,
                        ),
                        itemBuilder: (context, index) {
                            return _buildCategoryCard(_categories[index]);
                        },
                    ),
                ),
                const SizedBox(height: 30),

                _buildRecentlyAddedSection(),

                const SizedBox(height: 30),
            ],
        ),
    );
  }
}
