// المسار: lib/widgets/manufacturers_banner.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/manufacturers_provider.dart';
import 'package:my_test_app/models/manufacturer_model.dart';
import 'package:google_fonts/google_fonts.dart'; // 💡 استدعاء Google Fonts لتحسين الخط

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

    // 💡 تحديد لون أساسي للبطاقة (أزرق/أخضر داكن)
    final Color primaryColor = Theme.of(context).primaryColor;
    
    final Widget iconContent;
    if (isAllOption) {
      // 💡 إذا كان الخيار هو "عرض الكل"، نستخدم أيقونة مخصصة
      iconContent = Icon(
        Icons.filter_list_alt, // أيقونة لتمثيل "عرض الكل" أو التصفية (أكثر حداثة من list_alt)
        size: 32,
        color: primaryColor, // استخدام لون التطبيق الأساسي
      );
    } else {
      // للشركات العادية، نعرض الحرف الأول
      iconContent = Text(
        manufacturer.name.isNotEmpty ? manufacturer.name[0] : 'ش',
        // 💡 [تحسين 1]: استخدام Google Fonts للحرف
        style: GoogleFonts.cairo(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: primaryColor,
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
        margin: const EdgeInsets.symmetric(horizontal: 4.0), // تقليل الهامش قليلاً
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 💡 [تحسين 2]: تحسين مظهر الدائرة والظل
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  // 💡 ظل أنعم وأكثر انتشاراً
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    spreadRadius: 0.5,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 32, // تكبير الدائرة قليلاً
                backgroundColor: Colors.white, // خلفية بيضاء
                child: iconContent, // استخدام محتوى الأيقونة المحدد مسبقاً
              ),
            ),
            const SizedBox(height: 5),

            // 💡 [تحسين 3]: تحسين مظهر اسم الشركة ومعالجة قطع النص
            Text(
              manufacturer.name,
              textAlign: TextAlign.center,
              maxLines: 2, // 💥💥 [تصحيح] زيادة الحد الأقصى للأسطر لمعالجة مشكلة قطع النص 💥💥
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600, // سُمك الخط: Semi-Bold
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
    return Container(
      // 💡 [تحسين 4]: إضافة لون خلفية خفيف للبانر نفسه ليميزه
      color: Colors.grey.shade50, // خلفية فاتحة جدًا
      // 💥💥 [تصحيح]: زيادة الـ Padding السفلي لزيادة المسافة عن المنتجات 💥💥
      padding: const EdgeInsets.only(top: 5.0, bottom: 10.0), 
      child: Consumer<ManufacturersProvider>(
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
            // إذا كانت القائمة فارغة
            return const SizedBox.shrink();
          }

          // عرض القائمة الأفقية (ListView.builder)
          return SizedBox(
            height: 105, // ارتفاع مناسب للبانر
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
      ),
    );
  }
}
