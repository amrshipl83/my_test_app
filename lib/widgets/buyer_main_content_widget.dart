// lib/widgets/buyer_main_content_widget.dart   
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // نحتاج لاستيراد Timer
import 'package:my_test_app/providers/buyer_data_provider.dart';

// ⭐️ تحويل الـ Widget إلى Stateful لتمكين الدوران التلقائي ⭐️
class BuyerMainContentWidget extends StatefulWidget {
  const BuyerMainContentWidget({super.key});

  @override                                     
  State<BuyerMainContentWidget> createState() => _BuyerMainContentWidgetState();
}

class _BuyerMainContentWidgetState extends State<BuyerMainContentWidget> {                      
  // المتغيرات الجديدة للتحكم في دوران الصور
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {                            
    super.initState();
    _pageController = PageController(initialPage: 0);                                           
    // نستخدم Future.microtask لضمان بدء الـ Timer بعد بناء السياق (context)                    
    Future.microtask(() => _startTimer());
  }                                                                                             

  void _startTimer() {
    final buyerDataProvider = Provider.of<BuyerDataProvider>(context, listen: false);
    // ننتظر قليلاً للتأكد من تحميل البيانات الأولية                                             
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;                                                                     

      // نبدأ الـ Timer فقط إذا كان هناك بانرات متاحة                                           
      if (buyerDataProvider.banners.isNotEmpty) {
        _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {                     
          if (!mounted) return;                 
          final bannersCount = buyerDataProvider.banners.length;
                                                
          if (bannersCount > 0) {               
            // الانتقال إلى الصفحة التالية أو العودة للأول                                      
            if (_currentPage < bannersCount - 1) {
              _currentPage++;                   
            } else {                            
              _currentPage = 0;                 
            }
                                                
            _pageController.animateToPage(      
              _currentPage,                     
              duration: const Duration(milliseconds: 600),                                      
              curve: Curves.easeIn,             
            );
          }                                     
        });
      }
    });
  }

  @override                                     
  void dispose() {
    _timer?.cancel();                           
    _pageController.dispose();
    super.dispose();
  }
                                                
  @override
  Widget build(BuildContext context) {
    // ⭐️⭐️ 1. الاستماع إلى مزود البيانات (Provider) ⭐️⭐️
    final buyerDataProvider = context.watch<BuyerDataProvider>();                               
    final categories = buyerDataProvider.categories;
    final banners = buyerDataProvider.banners;                                                  
    const Color sectionHeadingColor = Color(0xFF2c3e50);

    // 💡 لم نعد نحتاج لفحص isLoading/errorMessage هنا، لأن الوالد BuyerHomeScreen يفعل ذلك.

    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),        
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,                                         
        children: <Widget>[                     
          // ⭐️ قسم الأقسام الرئيسية (Categories) ⭐️
          Center(                               
            child: Text(                        
              'الأقسام الرئيسية',               
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: sectionHeadingColor),                                          
            ),                                  
          ),
          const SizedBox(height: 20),           
          // 💡 نمرر البيانات الحقيقية من المزود
          _buildCategoriesGrid(context, categories),                                                                                            
          const SizedBox(height: 30),
                                                
          // ⭐️ قسم العروض المميزة (Banner Slider) ⭐️                                           
          Center(                               
            child: Text(                        
              'عروض مميزة',                     
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: sectionHeadingColor),                                          
            ),                                  
          ),                                    
          const SizedBox(height: 15),           
          // 💡 نستخدم الدالة الجديدة التي تعتمد على PageView                                   
          _buildBannerSlider(context, banners),                                                 
          const SizedBox(height: 30),           
          // يمكنك إضافة المزيد من الأقسام هنا (مثل المنتجات الأكثر مبيعًا)                      
        ],                                      
      ),                                        
    );                                          
  }

  // ⭐️ ------------------------------------------------------------------ ⭐️
  // ⭐️ دوال البناء الفرعية ⭐️                  
  // ⭐️ ------------------------------------------------------------------ ⭐️
                                                
  Widget _buildCategoriesGrid(BuildContext context, List<Category> categories) {                
    if (categories.isEmpty) {
      return const Center(child: Text('لا توجد أقسام متاحة حالياً.', style: TextStyle(color: Colors.grey)));                                     
    }                                                                                           

    return GridView.builder(                    
      shrinkWrap: true,                         
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(                             
        maxCrossAxisExtent: 250,
        childAspectRatio: 1.5,                  
        crossAxisSpacing: 20,                   
        mainAxisSpacing: 20,                    
      ),
      itemCount: categories.length,             
      itemBuilder: (context, index) {           
        final category = categories[index];
        return InkWell(                         
          onTap: () {
            // 💡 التوجيه إلى صفحة الأقسام باستخدام اسم القسم
            // Navigator.of(context).pushNamed('/category', arguments: category.name);          
          },                                    
          child: Container(                     
            decoration: BoxDecoration(          
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(15),                                          
              boxShadow: [                      
                BoxShadow(                      
                  // 💡 تم تقليل قيمة التعتيم و blurRadius للظل (Elevation أقل)
                  color: Theme.of(context).shadowColor.withOpacity(0.05), 
                  blurRadius: 5, 
                  offset: const Offset(0, 2),
                ),
              ],                                
            ),
            child: Column(                      
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 💡 تكبير مساحة الصورة (Expanded flex: 4)
                Expanded(
                  flex: 4, 
                  child: ClipRRect(                      
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: Image.network(         
                      category.imageUrl,          
                      // تم إزالة height: 80 والاعتماد على Expanded
                      width: double.infinity,
                      fit: BoxFit.cover,          
                      errorBuilder: (c, o, s) => Container(                                       
                        // تم إزالة height: 80
                        color: Colors.grey.shade200,                                              
                        child: const Center(child: Icon(FontAwesomeIcons.image, size: 30, color: Colors.grey)),                                   
                      ),
                    ),
                  ),
                ),                              
                // 💡 تقليل مساحة النص (Expanded flex: 1)
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),                                           
                    child: Center(
                      child: Text(                  
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), // تصغير الخط قليلاً
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis, // إضافة لتجنب تخريب التنسيق
                      ),
                    ),
                  ),
                ),                              
              ],                                
            ),                                  
          ),
        );
      },                                        
    );                                          
  }                                                                                             

  Widget _buildBannerSlider(BuildContext context, List<BannerItem> banners) {                   
    if (banners.isEmpty) {                      
      return const SizedBox.shrink(); // display: none                                          
    }

    // 💡 تم تعديل نسبة العرض/الارتفاع لتقليل ارتفاع البانر الكلي (مثلاً 3.0 لنسبة 3:1)
    const double aspectRatio = 3.0; // كانت 4.44
                                                
    return Column(                              
      children: [                               
        Container(                              
          height: MediaQuery.of(context).size.width / aspectRatio, // الارتفاع الجديد أقل
          decoration: BoxDecoration(            
            borderRadius: BorderRadius.circular(15),                                            
            boxShadow: [                        
              BoxShadow(
                color: Colors.black.withOpacity(0.15),                                          
                blurRadius: 15,                 
                offset: const Offset(0, 4),     
              ),                                
            ],                                  
          ),                                    
          child: ClipRRect(                     
            borderRadius: BorderRadius.circular(15),                                            
            // ⭐️ استخدام PageView.builder بدلاً من CarouselSlider ⭐️                            
            child: PageView.builder(            
              controller: _pageController,
              itemCount: banners.length,        
              onPageChanged: (index) {
                // تحديث مؤشر الصفحة ليعمل مؤشر النقاط بشكل صحيح                                
                setState(() {                   
                  _currentPage = index;
                });                             
              },
              itemBuilder: (BuildContext context, int index) {                                  
                final banner = banners[index];  
                return Image.network(
                  banner.imageUrl,              
                  fit: BoxFit.cover,
                  width: double.infinity,       
                  errorBuilder: (c, o, s) => Container(                                         
                    color: Colors.grey.shade300,
                    child: const Center(child: Text('عرض مميز', style: TextStyle(color: Colors.black))),                                        
                  ),                            
                );                              
              },                                
            ),
          ),                                    
        ),
        const SizedBox(height: 10),
        // مؤشرات الصفحات (Dots Indicators)     
        Row(
          mainAxisAlignment: MainAxisAlignment.center,                                          
          children: banners.asMap().entries.map((entry) {                                       
            return Container(                   
              width: 8.0,                       
              height: 8.0,                      
              margin: const EdgeInsets.symmetric(horizontal: 4.0),                              
              decoration: BoxDecoration(        
                shape: BoxShape.circle,
                color: (Theme.of(context).primaryColor)                                         
                  .withOpacity(_currentPage == entry.key ? 0.9 : 0.3),                          
              ),
            );                                  
          }).toList(),                          
        ),                                      
      ],
    );                                          
  }
}
