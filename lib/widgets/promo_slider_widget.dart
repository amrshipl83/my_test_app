// lib/widgets/promo_slider_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/consumer/consumer_data_models.dart';

class PromoSliderWidget extends StatefulWidget {
  final List<ConsumerBanner> banners;
  final double height;

  const PromoSliderWidget({super.key, required this.banners, this.height = 160});

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
      if (widget.banners.length > 1) {
        _currentPage = (_currentPage + 1) % widget.banners.length;
        _pageController.animateToPage(_currentPage, 
            duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
      }
    });
  }

  // 🎯 هنا المنطق المعقد اللي بتقول عليه
  void _handleNavigation(ConsumerBanner banner) {
    print("Navigating to: ${banner.targetType} with ID: ${banner.targetId}");
    
    switch (banner.targetType) {
      case 'store':
        // Navigator.pushNamed(context, '/storeDetails', arguments: banner.targetId);
        break;
      case 'category':
        // Navigator.pushNamed(context, '/categoryProducts', arguments: banner.targetId);
        break;
      case 'external':
        // launchUrl(Uri.parse(banner.targetId));
        break;
      default:
        print("No action for this banner");
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
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _handleNavigation(widget.banners[index]),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: widget.banners[index].imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildDotsIndicator(),
      ],
    );
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.banners.asMap().entries.map((entry) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _currentPage == entry.key ? 20 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _currentPage == entry.key ? Colors.green[700] : Colors.grey[300],
          ),
        );
      }).toList(),
    );
  }
}
