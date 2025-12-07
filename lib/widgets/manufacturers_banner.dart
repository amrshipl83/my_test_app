// المسار: lib/widgets/manufacturers_banner.dart        
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/manufacturers_provider.dart';
import 'package:my_test_app/models/manufacturer_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
class ManufacturersBanner extends StatefulWidget {
  final Function(String? id) onManufacturerSelected;      
  const ManufacturersBanner({
    super.key,
    required this.onManufacturerSelected,               
  });                                                   
  @override
  State<ManufacturersBanner> createState() => _ManufacturersBannerState();
}

class _ManufacturersBannerState extends State<ManufacturersBanner> {

  @override
  void initState() {
    super.initState();                                      
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ManufacturersProvider>(context, listen: false).fetchManufacturers();                          
    });
  }                                                                                                             

  Widget _buildManufacturerCard(ManufacturerModel manufacturer) {
    final bool isAllOption = manufacturer.id == 'ALL';  
    final Color primaryColor = Theme.of(context).primaryColor;
                                                            
    final double radius = 9.w; 
    final double iconSize = 0.5 * radius;
                                                                                                                    
    final Widget iconContent;
    if (isAllOption) {
      iconContent = Icon(
        Icons.filter_list_alt,                          
        size: iconSize,
        color: primaryColor,                                                                                          
      );
    } else {
      iconContent = manufacturer.name.isNotEmpty
          ? Text(
              manufacturer.name[0],                                   
              style: GoogleFonts.cairo(
                fontSize: 16.sp, 
                fontWeight: FontWeight.w700,                            
                color: primaryColor,                                  
              ),
            )
          : Icon(Icons.business, size: iconSize, color: primaryColor);
    }                                                   
    return InkWell(                                           
      onTap: () {
        widget.onManufacturerSelected(manufacturer.id);
      },                                                      
      child: Container(
        width: 25.w,                                            
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [                                              
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),                                                                           
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],                                                    
              ),
              child: CircleAvatar(
                radius: radius, 
                backgroundColor: Colors.white,                          
                child: iconContent,
              ),                                                    
            ),
            // 🚀 [تصحيح 3]: تقليل المسافة العمودية من 3 إلى 2 لزيادة الاحتياطي
            const SizedBox(height: 2), // تم التعديل
                                                                    
            Text(                                                                                                             
              manufacturer.name,
              textAlign: TextAlign.center,              
              maxLines: 2,                                                                                                    
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 9.sp, 
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),                                                    
      ),                                                    
    );
  }                                                                                                               
  @override
  Widget build(BuildContext context) {                      
    // 🚀 [تصحيح 5]: تقليل ارتفاع البانر الكلي للمرة الأخيرة من 12.h إلى 11.h
    final double bannerHeight = 11.h; // <--- التعديل النهائي 🚀
                                                          
    return Container(
      color: Colors.white,                                    
      // زيادة الـ Padding السفلي لزيادة المسافة عن المنتجات 
      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),                                                                                                                
      child: Consumer<ManufacturersProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return SizedBox(                            
              height: bannerHeight,                                   
              child: const Center(child: CircularProgressIndicator())
            );                                          
          }
                                                        
          if (provider.errorMessage != null) {
            return SizedBox(
              height: bannerHeight,                     
              child: Center(child: Text('خطأ في التحميل: ${provider.errorMessage}',
              style: const TextStyle(color: Colors.red)))
            );
          }
                                                        
          if (provider.manufacturers.isEmpty) {
            return const SizedBox.shrink();                                                                               
          }
                                                                  
          return SizedBox(                                          
            height: bannerHeight, // استخدام الارتفاع الديناميكي المُعدل
            child: ListView.builder(
              scrollDirection: Axis.horizontal,                                                                               
              padding: const EdgeInsets.symmetric(horizontal: 8.0),                                                                                                                   
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
