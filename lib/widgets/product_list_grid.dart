// المسار: lib/widgets/product_list_grid.dart   

import 'package:flutter/material.dart';         
import 'package:cloud_firestore/cloud_firestore.dart';                                          
import 'package:provider/provider.dart'; // 💡 لإضافة ChangeNotifierProvider                    
import 'package:my_test_app/widgets/buyer_product_card.dart'; // ✅ ضمان استدعاء البطاقة
import 'package:my_test_app/providers/product_offers_provider.dart'; // ✅ ضمان استدعاء الـ Provider                                            
                                                
class ProductListGrid extends StatelessWidget {
  final String subCategoryId;                                                                     
  final String pageTitle; 
  // 💡 [تعديل 1]: إضافة الحقل الجديد لفلترة الشركات (حل خطأ البناء)
  final String? manufacturerId; 

  const ProductListGrid({
    super.key,
    required this.subCategoryId,                    
    required this.pageTitle,
    // 💡 [تعديل 2]: استقبال الحقل الجديد في المُنشئ
    this.manufacturerId, 
  });
                                                  
  Stream<QuerySnapshot> _getProductsStream() {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    // 💡 [تعديل 3]: بناء الاستعلام وتضمين شرط التصفية بالشركات المصنعة
    Query productsQuery = db.collection('products')                                                   
      .where('subId', isEqualTo: subCategoryId)       
      .where('status', isEqualTo: 'active')           
      .orderBy('order', descending: false);                                                         
    
    // 💡 تطبيق التصفية الإضافية إذا تم تحديد شركة مصنعة
    if (manufacturerId != null) {
      productsQuery = productsQuery.where('manufacturerId', isEqualTo: manufacturerId);
    }
    
    return productsQuery.snapshots();
  }                                                                                             
  
  @override                                       
  Widget build(BuildContext context) {
    if (subCategoryId.isEmpty) {                      
      return const Center(child: Text('خطأ: لم يتم تحديد القسم الفرعي لعرض المنتجات.'));
    }                                           
    
    return StreamBuilder<QuerySnapshot>(
      stream: _getProductsStream(),                   
      builder: (context, snapshot) {                    
        if (snapshot.connectionState == ConnectionState.waiting) {                                        
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4A6491))
          );
        }
                                                        
        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ في تحميل المنتجات: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(                                   
              padding: const EdgeInsets.all(20.0),                                                            
              child: Text(                                      
                // عرض رسالة مختلفة إذا كانت القائمة مفلترة
                manufacturerId != null 
                    ? 'لا توجد منتجات لهذه الشركة المصنعة في قسم "$pageTitle".'
                    : 'لا توجد منتجات متاحة حاليًا في قسم "$pageTitle".',                                              
                textAlign: TextAlign.center,
              ),                                            
            ),                                            
          );                                            
        }
                                                        
        final products = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,                              
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,                            
            childAspectRatio: 0.48, // الحل النهائي لـ Overflow
          ),
          itemBuilder: (context, index) {
            final productDoc = products[index];
            final productId = productDoc.id;

            // 💥 التعديل الجذري: تغليف كل بطاقة بـ ChangeNotifierProvider خاص بها                          
            return ChangeNotifierProvider<ProductOffersProvider>(
              // نمرر الـ productId إلى Provider عند إنشائه لأول مرة                                          
              create: (_) => ProductOffersProvider(productId: productId),                                     
              child: BuyerProductCard(
                productId: productId,
                productData: productDoc.data() as Map<String, dynamic>
              ),
            );
          },
        );
      },
    );
  }                                             
}                                               
