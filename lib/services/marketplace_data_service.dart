// lib/services/marketplace_data_service.dart                                                             
import 'package:cloud_firestore/cloud_firestore.dart';                                                    
import 'package:my_test_app/models/banner_model.dart';                                                    

// 🟢 [التصحيح النهائي]: إعادة إضافة استيراد CategoryModel الصحيح
import 'package:my_test_app/models/category_model.dart'; 

import 'package:my_test_app/models/product_model.dart'; // ✅ نحتاج هذا لاستخدامه داخل الدالة الجديدة     
import 'package:my_test_app/models/offer_model.dart'; // ✅ نحتاج هذا لاستخدامه داخل الدالة الجديدة                                                                                                                 

class MarketplaceDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
                                                       
  // 1. جلب البانرات لمتجر معين                        
  Future<List<BannerModel>> fetchBanners(String ownerId) async {                                              
    try {                                                  
      final bannersQuery = await _db.collection('consumerBanners')                                                  
          .where('status', isEqualTo: 'active')                
          .where('ownerId', isEqualTo: ownerId)                
          .orderBy('order', descending: false) // ترتيب كما في HTML
          .get();                                                                                               
      
      return bannersQuery.docs.map((doc) {                   
        final data = doc.data();                             
        return BannerModel(                                    
          id: doc.id,                                          
          imageUrl: data['imageUrl'] ?? '',                    
          url: data['url'],                                    
          altText: data['altText'],                            
          order: (data['order'] as num?)?.toInt() ?? 0,                                                             
          status: 'active', // 🟢 التصحيح: إضافة المعامل 'status'                                                 
        );                                                 
      }).toList();                                                                                            
    } catch (e) {                                          
      // يجب أن يتم إظهار الخطأ في FutureBuilder           
      throw Exception('فشل جلب البانرات: $e');           
    }                                                  
  }                                                                                                         

  // 2. جلب الأقسام بناءً على عروض المتجر (تقليد المنطق المعقد في JavaScript)                                
  Future<List<CategoryModel>> fetchCategoriesByOffers(String ownerId) async {                                                                                      
    try {
      // 1. جلب العروض المرتبطة بالمتجر                    
      final offersSnapshot = await _db.collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)
          .get();                                                                                               
      
      if (offersSnapshot.docs.isEmpty) return [];    
      
      // 2. استخلاص معرفات المنتجات من العروض              
      final productIds = offersSnapshot.docs                   
          .map((doc) => doc.data()['productId'] as String?)                                                         
          .where((id) => id != null)
          .toSet();
                                                           
      if (productIds.isEmpty) return [];                                                                        
      
      // 3. جلب وثائق المنتجات لاستخلاص mainId (يجب أن يتم ذلك في دفعات إذا كان العدد كبيراً)                    
      // ملاحظة: Firestore لا تسمح بـ `whereIn` لأكثر من 10 عناصر، لذا نستخدم `Future.wait`                     
      final productsFutures = productIds.map((id) => _db.collection('products').doc(id!).get());                
      final productsSnapshots = await Future.wait(productsFutures);                                                                                                                                                       
      
      // 4. استخلاص معرفات الأقسام الرئيسية                
      final mainCategoryIds = productsSnapshots                
          .where((doc) => doc.exists)                          
          .map((doc) => doc.data()?['mainId'] as String?)                                                           
          .where((id) => id != null)                           
          .toSet();                                                                                             
      
      if (mainCategoryIds.isEmpty) return [];                                                                   
      
      // 5. جلب وثائق الأقسام الرئيسية وتصفية 'active'                                                          
      final categoriesFutures = mainCategoryIds.map((id) => _db.collection('mainCategory').doc(id!).get());                                                          
      final categoriesSnapshots = await Future.wait(categoriesFutures);                                   
      
      final List<CategoryModel> activeCategories = [];                                                                                                               
      for (var docSnap in categoriesSnapshots) {             
        if (docSnap.exists) {
          final data = docSnap.data();                                                                              
          // 🟢🟢 [التصحيح النهائي 1]: قراءة الحقل status وتحويله إلى String للمقارنة 🟢🟢                          
          final statusString = data?['status']?.toString().toLowerCase();
                                                               
          // 🟢🟢 [التصحيح النهائي 2]: تحويل القيمة String ('active') إلى Bool 🟢🟢                                 
          final isActive = statusString == 'active';                                                                
          
          if (isActive) {
            // الآن CategoryModel متاح لأنه تم استيراده بشكل صحيح                    
            activeCategories.add(CategoryModel(                    
              id: docSnap.id,
              name: data?['name'] ?? 'قسم غير مسمى',               
              imageUrl: data?['imageUrl'] ?? '',
              order: (data?['order'] as num?)?.toInt() ?? 0,                                                            
              // تمرير القيمة Bool المصححة                         
              status: isActive,                                  
            ));                                                
          }
        }                                                  
      }                                                                                                         
      
      // 6. الفرز                                          
      activeCategories.sort((a, b) => a.order.compareTo(b.order));                                                                                                   
      
      return activeCategories;                                                                                
    } catch (e) {
      throw Exception('فشل جلب الأقسام بناءً على العروض: $e');                                                 
    }                                                  
  }
                                                       
  // 3. جلب الأقسام الفرعية (SubCategories) بناءً على عروض المتجر والقسم الرئيسي                             
  Future<List<CategoryModel>> fetchSubCategoriesByOffers(String mainCategoryId, String ownerId) async {
    try {                                                  
      // 1. استعلام العروض بناءً على ownerId                
      final offersSnapshot = await _db.collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)                
          .get();                                                                                               
      
      if (offersSnapshot.docs.isEmpty) return [];
                                                           
      // 2. استخراج معرفات المنتجات الفريدة من العروض      
      final productIds = offersSnapshot.docs
          .map((doc) => doc.data()['productId'] as String?)                                                         
          .where((id) => id != null)
          .toSet();

      if (productIds.isEmpty) return [];                                                                        
      
      // 3. جلب وثائق المنتجات لاستخلاص subId
      final productDocsPromises = productIds.map((id) => _db.collection('products').doc(id!).get());
      final productDocs = await Future.wait(productDocsPromises);                                                                                                    
      
      // 4. استخراج معرفات الأقسام الفرعية الفريدة التي تنتمي للقسم الرئيسي الحالي                              
      final subCategoryIds = <String>{};
      for (var productDoc in productDocs) {                  
        if (productDoc.exists) {                               
          final productData = productDoc.data();               
          // 💡 التحقق من الانتماء للقسم الرئيسي الحالي                                                             
          if (productData?['mainId'] == mainCategoryId && productData?['subId'] != null) {                            
            subCategoryIds.add(productData!['subId'] as String);                                                    
          }                                                  
        }
      }                                                                                                         
      
      if (subCategoryIds.isEmpty) return [];                                                                    
      
      // 5. جلب وثائق الأقسام الفرعية وتصفية 'active'      
      final subCategoriesPromises = subCategoryIds.map((id) => _db.collection('subCategory').doc(id).get());                                                         
      final subCategoriesDocs = await Future.wait(subCategoriesPromises);                                                                                            
      
      final List<CategoryModel> activeSubCategories = [];
                                                           
      for (var docSnap in subCategoriesDocs) {
        if (docSnap.exists) {                                  
          final data = docSnap.data();                         
          final statusString = data?['status']?.toString().toLowerCase();                                           
          final isActive = statusString == 'active';
          
          // 🟢 نستخدم نفس منطق التصحيح (تحويل String إلى Bool للموديل)                                             
          if (isActive) {                                        
            activeSubCategories.add(CategoryModel(
              id: docSnap.id,                                      
              name: data?['name'] ?? 'قسم فرعي غير مسمى',                                                               
              imageUrl: data?['imageUrl'] ?? '',                   
              order: (data?['order'] as num?)?.toInt() ?? 0,
              status: isActive, // تمرير القيمة Bool
            ));                                                
          }                                                  
        }
      }                                              
      
      // 6. الفرز                                          
      activeSubCategories.sort((a, b) => a.order.compareTo(b.order));                                     
      
      return activeSubCategories;                                                                             
    } catch (e) {                                          
      throw Exception('فشل جلب الأقسام الفرعية بناءً على العروض: $e');                                         
    }
  }                                                  
  
  // 🎯🎯 [تمت إضافتها لحل الخطأ رقم 1 في الشاشة] 🎯 🎯
  // 4. جلب المنتجات والعروض حسب القسم الفرعي والمتجر  
  Future<List<Map<String, dynamic>>> fetchProductsAndOffersBySubCategory({                                    
    required String ownerId,                             
    required String mainId,                              
    required String subId,                             
  }) async {                                             
    try {
      // 1. جلب العروض التي تنتمي لهذا المتجر              
      final offersSnapshot = await _db.collection('marketOffer')                                                    
          .where('ownerId', isEqualTo: ownerId)                
          .get();                                    
      
      if (offersSnapshot.docs.isEmpty) return [];    
      
      // 2. استخراج معرفات المنتجات من العروض              
      final productIds = offersSnapshot.docs                   
          .map((doc) => doc.data()['productId'] as String?)
          .where((id) => id != null)                           
          .toSet();
                                                           
      if (productIds.isEmpty) return [];             
      
      // 3. جلب وثائق المنتجات التي تنتمي لهذا القسم الفرعي والرئيسي
      final productsQuery = await _db.collection('products')                                                        
          .where('mainId', isEqualTo: mainId)                  
          .where('subId', isEqualTo: subId)                    
          .where(FieldPath.documentId, whereIn: productIds.toList()) // تصفية المنتجات الموجودة في العروض           
          .get();                                    
      
      final List<Map<String, dynamic>> results = []; 
      for (var productDoc in productsQuery.docs) {           
        final productId = productDoc.id;                     
        final productData = productDoc.data();                                                                    
        
        // 4. البحث عن العرض المطابق                         
        final offerDoc = offersSnapshot.docs.firstWhere(                                                                
          (doc) => doc.data()['productId'] == productId,                                                        
          // إذا لم نجد عرضًا، نتخطى هذا المنتج 
          orElse: () => throw Exception('Offer not found for product $productId'),
        );                                                                                                        
        
        // 5. بناء النماذج (نفترض وجود fromFirestore في ProductOfferModel و ProductModel)                         
        final offerModel = ProductOfferModel.fromFirestore(offerDoc.data(), offerDoc.id);                                                                              
        
        // بناء ProductModel                                 
        final productModel = ProductModel(                     
          id: productId,                                       
          name: productData['name'] ?? 'منتج غير مسمى',                                                             
          mainCategoryId: productData['mainId'],               
          subCategoryId: productData['subId'],
          // ✅ تم تصحيح هذا ليعمل مع التعريف الجديد (List<String>)
          imageUrls: List<String>.from(productData['imageUrls'] ?? []),                                             
          displayPrice: (productData['displayPrice'] as num?)?.toDouble(),                                          
          isAvailable: productData['isAvailable'] ?? true,
        );                                                                                                        
        
        results.add({                                          
          'product': productModel,                             
          'offer': offerModel,                               
        });                                                
      }                                                                                                         
      
      return results;                                                                                         
    } catch (e) {                                          
      // في حال تجاوزنا حد whereIn (10 عناصر)، يمكن تقسيم الاستعلام                                             
      throw Exception('فشل جلب المنتجات والعروض: $e');                                                        
    }                                                  
  }
}
