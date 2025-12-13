// lib/models/product_model.dart

class ProductModel {
  final String id;
  final String name;
  final String? mainCategoryId;
  final String? subCategoryId;
  
  // 🟢 [التصحيح 1]: تم تغيير 'imageUrl' إلى 'imageUrls' (List<String>)
  final List<String> imageUrls; 
  
  final double? displayPrice;
                                                                               
  // خاص بالـ MarketOffer                              
  final bool isAvailable;
                                                       
  ProductModel({
    required this.id,
    required this.name,
    this.mainCategoryId,
    this.subCategoryId,
    // 🟢 [التصحيح 2]: تغيير التوقيع لاستقبال List<String>
    required this.imageUrls, 
    this.displayPrice,
    this.isAvailable = true,
  });
}                                                                                                        
// ❌ [التصحيح 3]: تم حذف التعريف المتعارض لـ CategoryModel 
// class CategoryModel {                                  
//   final String id;
//   final String name;                                                                                        
//   CategoryModel({required this.id, required this.name});                                                  
// }                                                                                                         

// enum لخيارات الفرز                                
enum ProductSortOption {                               
  nameAsc,                                             
  nameDesc,                                            
  priceAsc,                                            
  priceDesc,                                         
}
