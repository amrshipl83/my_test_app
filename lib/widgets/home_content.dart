// المسار: lib/widgets/home_content.dart        
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
  
  // --- Widgets البناء ---
  
  // ✅ الكود المُعدل: لضمان الشكل الدائري دون إطار أو مربع خلفي
  Widget _buildCategoryCard(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'قسم';
    final imageUrl = data['imageUrl'] as String? ?? ''; 

    Widget categoryIconOrImage;
    const double size = 80.0; // الحجم الثابت للصورة/الأيقونة

    if (imageUrl.isNotEmpty) {
        // 1. الصورة الفعلية: يتم عرضها كـ ClipOval مباشرة
        categoryIconOrImage = ClipOval(
            child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: size, 
                height: size,
                errorBuilder: (context, error, stackTrace) => 
                    // 2. حالة فشل التحميل: نعرض الأيقونة داخل دائرة (ClipOval) لتبدو كدائرة فقط
                    _buildDefaultCircularIcon(size),
                loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    // مؤشر تحميل خفيف
                    return Center(child: SizedBox(
                        width: size, height: size,
                        child: CircularProgressIndicator(
                            color: const Color(0xFF4CAF50),
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                        ),
                    ));
                },
            ),
        );
    } else {
        // 3. لا يوجد رابط صورة: نعرض الأيقونة داخل دائرة (ClipOval) لتبدو كدائرة فقط
        categoryIconOrImage = _buildDefaultCircularIcon(size);
    }

    return InkWell(
      onTap: () {                                       
        Navigator.of(context).pushNamed('/category', arguments: data['id']);                          
      },
      borderRadius: BorderRadius.circular(15), 
      child: Container(
        // هذا الـ Container هو بطاقة القسم بأكملها ويحمل الظل
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,                 
          children: [
            categoryIconOrImage, 
            const SizedBox(height: 8),                      
            Text(
              name,
              textAlign: TextAlign.center,                    
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF333333)),
              overflow: TextOverflow.ellipsis,              
            ),
          ],                                            
        ),
      ),
    );                                            
  }

  // دالة مساعدة لإنشاء الأيقونة الدائرية الافتراضية
  Widget _buildDefaultCircularIcon(double size) {
      return ClipOval(
          child: Container(
              width: size, 
              height: size,
              decoration: BoxDecoration(                        
                  color: Colors.white, 
                  shape: BoxShape.circle,                                                    
                  border: Border.all(color: const Color(0xFF4CAF50), width: 2),
              ),
              child: const Icon(Icons.shopping_bag_rounded, size: 30, color: Color(0xFF2c3e50)),
          ),
      );
  }


  Widget _buildBannerSlider() {
    if (_banners.isEmpty) return const SizedBox.shrink();                                       
    
    return Column(
      children: [
        Container(
          height: 180,
          margin: const EdgeInsets.symmetric(horizontal: 15.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: PageView.builder(                          
              controller: _bannerController,
              itemCount: _banners.length,
              itemBuilder: (context, index) {
                final banner = _banners[index];
                final imageUrl = banner['imageUrl'] as String? ?? 'https://via.placeholder.com/800x180/0f3460/f0f0f0?text=Banner';
                return InkWell(
                  onTap: () {
                    print('Banner clicked: ${banner['link']}');
                  },
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
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

  Widget _buildRecentlyAddedSection() {
    return Column(                                    
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 15.0, bottom: 10.0),
          child: Text(
            'أضيف حديثاً (مستطيلات افتراضية)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50)),
          ),
        ),                                              
        SizedBox(
          height: 150,
          child: ListView.builder(                          
            scrollDirection: Axis.horizontal,
            reverse: true,                                  
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(                                 
                width: 120,
                margin: EdgeInsets.only(right: 15, left: index == 0 ? 15 : 0),
                decoration: BoxDecoration(                        
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3)],
                ),                                              
                child: Center(child: Text('منتج ${index + 1}', style: TextStyle(color: Colors.grey.shade600))),
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
          _buildBannerSlider(),                           
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
                // ✅ القيمة النهائية لحل مشكلة الـ Overflow
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
