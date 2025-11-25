// المسار: lib/widgets/manufacturers_banner.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/manufacturers_provider.dart';
import 'package:my_test_app/models/manufacturer_model.dart';

class ManufacturersBanner extends StatefulWidget {
  // 💡 دالة يتم استدعاؤها عند اختيار شركة مصنعة
  final Function(String? id) onManufacturerSelected;

  const ManufacturersBanner({
    super.key,
    required this.onManufacturerSelected, // حقل مطلوب
  });

  @override
  State<ManufacturersBanner> createState() => _ManufacturersBannerState();
}

class _ManufacturersBannerState extends State<ManufacturersBanner> {
  @override
  void initState() {
    super.initState();
    // جلب البيانات فور بناء الـ Widget (بعد أول إطار)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ManufacturersProvider>(context, listen: false).fetchManufacturers();
    });
  }

  // 💡 ويدجت بناء بطاقة الشركة المصنعة
  Widget _buildManufacturerCard(ManufacturerModel manufacturer) {
    // 💡 [تعديل 1]: تحديد محتوى الدائرة بناءً على الـ ID
    final bool isAllOption = manufacturer.id == 'ALL';
    
    final Widget iconContent;
    if (isAllOption) {
      // 💡 إذا كان الخيار هو "عرض الكل"، نستخدم أيقونة مخصصة
      iconContent = const Icon(
        Icons.list_alt, // أيقونة لتمثيل "عرض الكل" أو القائمة
        size: 30,
        color: Color(0xFF4A6491), 
      );
    } else {
      // للشركات العادية، نعرض الحرف الأول
      iconContent = Text(
        manufacturer.name.isNotEmpty ? manufacturer.name[0] : 'ش',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4A6491), // اللون الأزرق الداكن
        ),
      );
    }

    // استخدام InkWell أو GestureDetector لالتقاط النقر
    return InkWell(
      onTap: () {
        // استدعاء الدالة التي تم تمريرها من الشاشة الرئيسية
        widget.onManufacturerSelected(manufacturer.id);
      },
      child: Container(
        width: 80, // عرض ثابت للبطاقة
        margin: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 💡 [تعديل 2]: استخدام ويدجت Container لإضافة ظل خفيف للدائرة
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  // 💡 إضافة ظل خفيف
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2), // ظل للأسفل قليلاً
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: iconContent, // استخدام محتوى الأيقونة المحدد مسبقاً
              ),
            ),
            const SizedBox(height: 5),
            // 💡 [تعديل 3]: حل مشكلة الخط الرفيع
            Text(
              manufacturer.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold, // سُمك الخط: Bold
                color: Colors.black87, // لون نص داكن واضح
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // استخدام Consumer للاستماع للتغييرات من ManufacturersProvider
    return Consumer<ManufacturersProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          // عرض دائرة تحميل في المنتصف أثناء جلب البيانات
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.errorMessage != null) {
          // عرض رسالة الخطأ
          return Center(child: Text('خطأ في التحميل: ${provider.errorMessage}',
              style: const TextStyle(color: Colors.red)));
        }

        if (provider.manufacturers.isEmpty) {
          // إذا كانت القائمة فارغة (وهذا غير محتمل بعد إضافة "عرض الكل")، يتم إخفاء الـ Widget
          return const SizedBox.shrink();
        }

        // عرض القائمة الأفقية (ListView.builder)
        return SizedBox(
          height: 100, // ارتفاع مناسب للبانر
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: provider.manufacturers.length,
            itemBuilder: (context, index) {
              final manufacturer = provider.manufacturers[index];
              return _buildManufacturerCard(manufacturer);
            },
          ),
        );
      },
    );
  }
}
