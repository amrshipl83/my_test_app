// المسار: lib/widgets/home_banner_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/buyer_data_provider.dart'; 
// 💡 نستخدم المسار الصحيح بافتراض أن widgets و models تحت lib
import '../models/banner_model.dart'; 

class HomeBannerWidget extends StatelessWidget {
  final double height;
  const HomeBannerWidget({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return Consumer<BuyerDataProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.banners.isEmpty) {
          // حالة التحميل الأولي
          return Container(
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(child: CircularProgressIndicator(color: Colors.black54)),
          );
        }

        if (provider.banners.isEmpty) {
          // لا توجد بانرات لعرضها
          return const SizedBox.shrink();
        }

        // عرض البانرات في كاروسيل (PageView)
        return SizedBox(
          height: height,
          child: PageView.builder(
            itemCount: provider.banners.length,
            controller: PageController(viewportFraction: 0.9), // عرض جزء من البانر التالي
            itemBuilder: (context, index) {
              final banner = provider.banners[index];
              // 💡 بما أننا نستخدم الآن dynamic في _BannerCard، لن يكون هناك خطأ تعيين نوع
              return _BannerCard(banner: banner); 
            },
          ),
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  // 💡 تم تغيير النوع إلى dynamic مؤقتاً لحل خطأ "Type not found"
  final dynamic banner; 
  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    // 💡 نستخدم طريقة الوصول لـ Map أو الكلاس حسب ما يتم تمريره
    // إذا كان كلاس BannerModel موجوداً، ستعمل الخاصية .name مباشرة
    final bannerName = banner?.name ?? (banner is Map ? banner['name'] : 'إعلان غير معرف');
    final bannerImageUrl = banner?.imageUrl ?? (banner is Map ? banner['imageUrl'] : null);
    
    return GestureDetector(
      onTap: () {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم النقر على إعلان: $bannerName')),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(left: 10, right: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.network(
            bannerImageUrl ?? 'https://placehold.co/600x400/2d9e68/ffffff?text=Image+Missing',
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFF2d9e68),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.gift, size: 40, color: Colors.white),
                        const SizedBox(height: 8),
                        Text(
                          bannerName ?? 'إعلان غير معروف',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'لا توجد صورة متاحة',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
