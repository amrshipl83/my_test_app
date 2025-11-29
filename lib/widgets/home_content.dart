// المسار: lib/widgets/home_content.dart
// تم تطبيق التحسينات النهائية على الـ UI لـ Banner، والأقسام، وقسم المنتجات الحديثة.
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
                                                
  // --- منطق جلب البيانات من Firestore (بدون تغيير) ---
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
                'link': doc['link'],
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

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadCategories(),
      _loadRetailerBanners(),
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

  // --- Widgets البناء المُحسَّنة ---

  // 💡 التحسين: إعادة ضبط أحجام الدائرة والخط للحصول على تناسق أفضل
  Widget _buildCategoryCard(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'قسم';
    final imageUrl = data['imageUrl'] as String? ?? '';

    Widget categoryIconOrImage;
    const double size = 55.0; // تم تقليل حجم الصورة/الأيقونة (كان 65)
    const double iconPadding = 8.0; 
    const double totalDiameter = size + iconPadding;

    if (imageUrl.isNotEmpty) {
        // 1. الصورة الفعلية
        categoryIconOrImage = ClipOval(
            child: Container(
                width: totalDiameter,
                height: totalDiameter,
                decoration: BoxDecoration(        
                    color: Colors.white,
                    shape: BoxShape.circle,       
                    border: Border.all(color: Colors.grey.shade300, width: 1), // إطار خفيف جداً
                ),
                child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: totalDiameter,
                    height: totalDiameter,
                    errorBuilder: (context, error, stackTrace) =>
                        // 2. حالة فشل التحميل
                        _buildDefaultCircularIcon(size),
                    loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(child: SizedBox(
                            width: totalDiameter * 0.5, height: totalDiameter * 0.5, // مؤشر أصغر
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
        // 3. لا يوجد رابط صورة
        categoryIconOrImage = _buildDefaultCircularIcon(size);
    }

    return InkWell(
      onTap: () {                               
        Navigator.of(context).pushNamed('/category', arguments: data['id']);                    
      },
      child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,       
          children: [
            categoryIconOrImage,
            const SizedBox(height: 5),          
            // 💡 التحسين: تم زيادة حجم الخط قليلاً لاسم القسم
            Text(
              name,
              textAlign: TextAlign.center,      
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF333333)), // كان 13
              overflow: TextOverflow.ellipsis,
              maxLines: 1, 
            ),
          ],                                    
        ),
    );                                          
  }

  // دالة مساعدة لإنشاء الأيقونة الدائرية الافتراضية
  Widget _buildDefaultCircularIcon(double size) {
      return ClipOval(
          child: Container(
              width: size + 8, // تناسق مع الحجم الفعلي
              height: size + 8,
              decoration: BoxDecoration(        
                  color: Colors.white,
                  shape: BoxShape.circle,       
                  border: Border.all(color: const Color(0xFF4CAF50), width: 1.5), 
              ),
              child: const Icon(Icons.category_rounded, size: 28, color: Color(0xFF2c3e50)), // أيقونة أصغر
          ),
      );
  }


  Widget _buildBannerSlider() {
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          height: 140, 
          // 💡 التحسين: تم إزالة الـ margin الأفقي هنا لأننا سنضعها في الـ Padding الخارجي في دالة build
          // margin: const EdgeInsets.symmetric(horizontal: 15.0),
          margin: const EdgeInsets.symmetric(horizontal: 0), // يتم التحكم فيه من الخارج
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 5)), 
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
                    print('Banner clicked: ${banner['link']}');
                  },
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover, // يضمن تغطية الحاوية بالصورة
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF4CAF50).withOpacity(0.5),
                      child: Center(child: Text(banner['name'] ?? 'عرض مميز', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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

  // 💡 بطاقة المنتج (لا يوجد تغيير كبير، فقط لضمان التناسق)
  Widget _buildProductCard(int index) {
    final List<Color> colors = [
      Colors.blue.shade100,
      Colors.green.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
      Colors.red.shade100,
    ];
    final color = colors[index % colors.length];

    return InkWell(
      onTap: () {
        print('Product ${index + 1} clicked');
      },
      child: Container(
        width: 150, 
        // 💡 التحسين: إضافة margin أفقي لجعل البطاقات منفصلة عن بعضها
        margin: const EdgeInsets.symmetric(horizontal: 5), // مسافة بين البطاقات
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
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
                child: Container(
                  color: color, 
                  child: Center(child: Icon(Icons.shopping_bag_rounded, size: 40, color: const Color(0xFF2c3e50).withOpacity(0.7))),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'منتج حديث ${index + 1}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2c3e50)),
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '125.00 ريال',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
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
    return Column(                              
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 15.0, left: 15.0, bottom: 8.0), // 💡 التحسين: padding متساوي وحجم أصغر للمسافة
          child: Text(
            'أضيف حديثاً', 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2c3e50)), // 💡 التحسين: حجم الخط 18 (كان 20)
          ),
        ),                                      
        SizedBox( 
          height: 220, 
          child: ListView.builder(              
            scrollDirection: Axis.horizontal,
            reverse: true,                      
            itemCount: 5, 
            itemBuilder: (context, index) {
              return Padding(
                // 💡 التحسين: إضافة padding جانبي للقائمة
                padding: EdgeInsets.only(
                  right: index == 4 ? 15 : 0, // padding لليمين في العنصر الأخير فقط
                  left: index == 0 ? 15 : 0,  // padding لليسار في العنصر الأول فقط
                ),
                child: _buildProductCard(index),
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
          // 💡 التحسين: وضع البانر داخل Padding لضمان عدم تلاصقه بالحواف
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
            // 💡 التحسين: إضافة Padding أفقي لشبكة الأقسام لحل مشكلة التلاصق
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: GridView.builder(            
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                // تم تعديل الـ AspectRatio ليناسب حجم الدائرة الجديدة والخط
                childAspectRatio: 0.8, // نسبة العرض/الارتفاع
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
