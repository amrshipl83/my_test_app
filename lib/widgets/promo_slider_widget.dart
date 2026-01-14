// lib/widgets/promo_slider_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/consumer/consumer_data_models.dart';

// المسارات الصحيحة
import '../screens/consumer/consumer_category_screen.dart'; 
import '../screens/consumer/consumer_product_list_screen.dart'; 
import '../screens/consumer/MarketplaceHomeScreen.dart'; 

class PromoSliderWidget extends StatefulWidget {
  final List<ConsumerBanner> banners;
  final double height;
  final String? currentOwnerId; 

  const PromoSliderWidget({
    super.key, 
    required this.banners, 
    this.height = 160,
    this.currentOwnerId,
  });

  @override
  State<PromoSliderWidget> createState() => _PromoSliderWidgetState();
}

class _PromoSliderWidgetState extends State<PromoSliderWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (widget.banners.isNotEmpty && widget.banners.length > 1) {
        _currentPage = (_currentPage + 1) % widget.banners.length;
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage, 
            duration: const Duration(milliseconds: 800), 
            curve: Curves.easeInOut
          );
        }
      }
    });
  }

  void _handleNavigation(ConsumerBanner banner) {
    // 🎯 التعديل الجوهري هنا: القراءة من linkType بدلاً من targetType 
    // لأن ده اللي بتبعته لوحة الإدارة فعلياً
    final String type = banner.targetType ?? banner.link ?? ''; 
    final String targetId = banner.targetId ?? '';
    final String name = banner.name ?? 'عرض خاص';

    // ملاحظة: لو الموديل عندك بيخزن linkType في متغير link، نستخدمه كبديل
    
    switch (type) {
      case 'CATEGORY':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConsumerCategoryScreen(
              mainCategoryId: targetId,
              categoryName: name,
            ),
          ),
        );
        break;

      case 'SUB_CATEGORY':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConsumerProductListScreen(
              mainCategoryId: '', 
              subCategoryId: targetId,
              manufacturerId: null,
            ),
          ),
        );
        break;

      case 'RETAILER':
      case 'SELLER': // أضفنا SELLER لأنها موجودة في بياناتك في الفايربيز
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarketplaceHomeScreen(
              currentStoreId: targetId,
              currentStoreName: name,
            ),
          ),
        );
        break;

      default:
        debugPrint("Unknown type: $type");
        // تنبيه بسيط في الـ Debug عشان تعرف لو فيه نوع جديد الإدارة بعتته
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return GestureDetector(
                onTap: () => _handleNavigation(banner),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: CachedNetworkImage(
                      imageUrl: banner.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildDotsIndicator(),
      ],
    );
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.banners.asMap().entries.map((entry) {
        return Container(
          width: _currentPage == entry.key ? 12 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _currentPage == entry.key ? Colors.green : Colors.grey,
          ),
        );
      }).toList(),
    );
  }
}
