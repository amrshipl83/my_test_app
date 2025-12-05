// المسار: lib/widgets/home_content.dart
// تم تحديث المنطق ليشمل: 1) التوجيه الصحيح للبانر عبر linkType/targetId. 2) جلب المنتجات الحديثة من Firestore. 3) توجيه المنتج الحديث لشاشة قائمة المنتجات عبر subId.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _db = FirebaseFirestore.instance;
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});
  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _banners = [];
  // 🎯 القائمة الجديدة لتخزين المنتجات الحديثة
  List<Map<String, dynamic>> _recentProducts = [];

  bool _isLoading = true;
  int _currentBannerIndex = 0;
  late PageController _bannerController;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBannerAutoSlide();
    });
  }
  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  // --- منطق جلب البيانات من Firestore ---

  Future<void> _loadCategories() async {
    // ... (منطق تحميل الأقسام - لم يتغير)
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
    // ... (منطق تحميل البانرات مع الحقول الجديدة - لم يتغير)
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
                // 🎯 الحقول الجديدة للتوجيه
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

  // 🎯 الدالة الجديدة لجلب المنتجات الحديثة (تم تصحيح جلب الصورة)
  Future<void> _loadRecentlyAddedProducts() async {
    try {
      // ✅ التعديل الأول: تغيير حقل الترتيب إلى 'createdAt'
      final q = _db.collection('products')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final querySnapshot = await q;
      final List<Map<String, dynamic>> loadedProducts = [];

      querySnapshot.docs.forEach((doc) {
         final data = doc.data();

         // 🎯 التعديل (5): استخراج الرابط الأول من مصفوفة imageUrls
         final List<dynamic>? urls = data['imageUrls'] as List<dynamic>?;
         final String firstImageUrl = (urls != null && urls.isNotEmpty)
                                       ? urls.first as String : '';

         loadedProducts.add({
            'id': doc.id,
            'name': data['name'] as String? ?? 'منتج',
            // ✅ استخدام الرابط المستخرج
            'imageUrl': firstImageUrl,
            // ✅ جلب معرف القسم الفرعي للتوجيه في التعديل الثالث
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
    // 🎯 إضافة دالة تحميل المنتجات إلى التحميل المتزامن
    await Future.wait([
      _loadCategories(),
      _loadRetailerBanners(),
      _loadRecentlyAddedProducts(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startBannerAutoSlide() {
    if (_banners.length > 1) {
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted || _banners.isEmpty) return;
        int nextPage = (_currentBannerIndex + 1) % _banners.length;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _startBannerAutoSlide();
      });
    }
  }

  // 🎯 منطق التعامل مع النقر على البانر (التعديل الرئيسي)
  void _handleBannerClick(String? linkType, String? targetId) {
    if (targetId == null || targetId.isEmpty || linkType == null) {
      // لا حاجة لرسالة خطأ إذا كان لا يوجد رابط، نتجاهل النقر ببساطة
      return;
    }

    final type = linkType.toUpperCase();

    if (type == 'EXTERNAL' && targetId.startsWith('http')) {
      // 🚀 لفتح رابط خارجي
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يتم فتح الرابط الخارجي: $targetId', textDirection: TextDirection.rtl)),
      );
      // في تطبيق حقيقي: launchUrl(Uri.parse(targetId));
    }
    else if (type == 'PRODUCT') {
      // 🚀 لفتح تفاصيل منتج
      Navigator.of(context).pushNamed(
        '/productDetails',
        arguments: targetId, // targetId = معرف المنتج
      );
    }
    else if (type == 'CATEGORY') {
      // 🚀 لفتح قائمة منتجات قسم رئيسي
      Navigator.of(context).pushNamed(
        '/products', // يفترض أن هذا المسار يدعم التصفية بالـ mainId
        arguments: {
          'mainId': targetId, // targetId = معرف القسم الرئيسي
          'subId': '',
        },
      );
    }
    else if (type == 'RETAILER') {
      // 🎯 الإضافة: التوجيه لصفحة عروض التاجر
      Navigator.of(context).pushNamed(
        '/retailerDetails', // المسار الذي يستقبل معرف التاجر
        arguments: targetId, // targetId = معرف التاجر/ownerId
      );
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('نوع الرابط غير مدعوم: $linkType', textDirection: TextDirection.rtl)),
      );
      debugPrint('Unsupported link type: $linkType');
    }
  }


  // --- Widgets البناء المُحسَّنة ---

  Widget _buildCategoryCard(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'قسم';
    final imageUrl = data['imageUrl'] as String? ?? '';

    Widget categoryIconOrImage;
    const double size = 55.0;
    const double iconPadding = 8.0;
    const double totalDiameter = size + iconPadding;

    if (imageUrl.isNotEmpty) {
        categoryIconOrImage = ClipOval(
            child: Container(
                width: totalDiameter,
                height: totalDiameter,
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    // 🔄 التعديل على Border.all
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: totalDiameter,
                    height: totalDiameter,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildDefaultCircularIcon(size),
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
      onTap: () {
        // هذا المسار يستخدم ID القسم الرئيسي
        Navigator.of(context).pushNamed('/categoryProducts', arguments: data['id']);
      },
      child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            categoryIconOrImage,
            const SizedBox(height: 5),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF333333)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
      ),
    );
  }

  Widget _buildDefaultCircularIcon(double size) {
      return ClipOval(
          child: Container(
              width: size + 8,
              height: size + 8,
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
              ),
              child: const Icon(Icons.category_rounded, size: 28, color: Color(0xFF2c3e50)),
      ),
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
              // 🔄 الاستبدال: Colors.black.withOpacity(0.12)
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
                    // 🎯 استخدام linkType و targetId
                    _handleBannerClick(banner['linkType'] as String?, banner['targetId'] as String?);
                  },
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      // 🔄 الاستبدال: const Color(0xFF4CAF50).withOpacity(0.5)
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

  // 🎯 تم تعديل هذه الدالة لإزالة السعر تمامًا وتعديل التوجيه
  Widget _buildProductCard(Map<String, dynamic> productData) {
    final name = productData['name'] as String? ?? 'منتج';
    final imageUrl = productData['imageUrl'] as String? ?? '';
    final productId = productData['id'] as String? ?? '';
    // ✅ جلب معرف القسم الفرعي subId
    final subId = productData['subId'] as String? ?? '';

    // قائمة ألوان بسيطة (للتجربة في حالة عدم وجود صورة)
    final List<Color> colors = [
      Colors.blue.shade100,
      Colors.green.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
      Colors.red.shade100,
    ];
    // نستخدم الـ ID لتحويله لرقم عشوائي ثابت للحصول على لون
    final colorIndex = (productId.hashCode % colors.length).abs();
    final color = colors[colorIndex];


    return InkWell(
      onTap: () {
        // 🎯 التعديل (6): تغيير المسار إلى '/products' ليطابق المسجل في main.dart
        if (subId.isNotEmpty) {
          Navigator.of(context).pushNamed(
            '/products', // ✅ المسار الصحيح الذي يستقبل SubId
            arguments: {
              'subId': subId,
              'mainId': '', // يفضل تمرير mainId فارغاً لتأكيد التصفية بـ subId فقط
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
            // 🔄 الاستبدال: Colors.black.withOpacity(0.08)
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.08).round()),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: color,
                          // 🔄 الاستبدال: const Color(0xFF2c3e50).withOpacity(0.7)
                          child: Center(child: Icon(Icons.shopping_bag_rounded, size: 40, color: const Color(0xFF2c3e50).withAlpha((255 * 0.7).round()))),
                        ),
                      )
                    : Container(
                        color: color,
                        // 🔄 الاستبدال: const Color(0xFF2c3e50).withOpacity(0.7)
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2c3e50)),
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                  ),
                  // ❌ تم حذف أي عرض للسعر
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildRecentlyAddedSection() {
    // 💡 التحقق: إذا لم يكن هناك منتجات، لا تعرض القسم
    if (_recentProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 15.0, left: 15.0, bottom: 8.0),
          child: Text(
            'أضيف حديثاً',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2c3e50)),
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            reverse: true,
            // 🎯 استخدام طول قائمة المنتجات الحقيقية
            itemCount: _recentProducts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == _recentProducts.length - 1 ? 15 : 0, // padding لليمين في العنصر الأخير فقط
                  left: index == 0 ? 15 : 0,  // padding لليسار في العنصر الأول فقط
                ),
                // 🎯 تمرير بيانات المنتج إلى الدالة
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
          const SizedBox(height: 20),

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
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
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
