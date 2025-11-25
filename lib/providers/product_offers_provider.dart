// المسار: lib/providers/product_offers_provider.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/utils/offer_data_model.dart'; // تأكد من المسار الصحيح للـ OfferModel

// تعريف فئة تمثل حالة العروض لمنتج معين
class ProductOffersProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 💡 إضافة حقل لتخزين هوية المنتج
  final String productId; 

  // 💡 إضافة المُنشئ (Constructor) لاستقبال هوية المنتج
  ProductOffersProvider({required this.productId}) {
    // فور إنشاء الـ Provider، نبدأ بجلب العروض لهذا المنتج
    fetchOffers(productId);
  }

  // 💡 متغيرات الحالة
  List<OfferModel> _availableOffers = [];
  OfferModel? _selectedOffer;                     
  bool _isLoading = true;                         
  int _currentQuantity = 0;
                                                  
  List<OfferModel> get availableOffers => _availableOffers;                                       
  OfferModel? get selectedOffer => _selectedOffer;                                                
  bool get isLoading => _isLoading;               
  int get currentQuantity => _currentQuantity;                                                                                                    
  
  // 💥 دالة جلب العروض
  Future<void> fetchOffers(String productId) async {
    // 1. نبدأ التحميل
    _isLoading = true;                              
    _availableOffers = [];                          
    _selectedOffer = null;
    notifyListeners(); // إخطار المستمعين ببدء التحميل

    try {                                             
      final offersQuery = _db.collection('productOffers')
        .where('productId', isEqualTo: productId)                                                       
        .where('status', isEqualTo: 'active');
                                                      
      final offersSnap = await offersQuery.get();                                                     
      List<OfferModel> allOffers = [];
                                                      
      for (var doc in offersSnap.docs) {
        // بما أنك تستخدم OfferModel.fromFirestore(doc)، نفترض أن هذه الدالة ترجع قائمة أو تقوم بالتحويل الصحيح
        // نعدلها لتعمل مع نموذج شائع
        // مثال: allOffers.add(OfferModel.fromDocument(doc)); 
        // سنفترض أن `OfferModel.fromFirestore(doc)` ترجع قائمة عروض من الوثيقة الواحدة، 
        // وهذا قد يكون منطقياً إذا كانت العروض مدمجة في وثيقة واحدة، ولكن هذا غير شائع.
        // للتأكد من استمرارية الكود المرسل:
        allOffers.addAll(OfferModel.fromFirestore(doc));
      }                                         
      // 2. تحديث الحالة
      _availableOffers = allOffers;             
      // اختيار العرض الافتراضي                       
      if (allOffers.isNotEmpty) {
        _selectedOffer = allOffers.first;               
        // تحديد الكمية الأولية بناءً على الحد الأدنى (minQty)
        _currentQuantity = _selectedOffer!.stock >= (_selectedOffer!.minQty ?? 1)                             
          ? (_selectedOffer!.minQty ?? 1)
          : 0;
      } else {                                          
        _currentQuantity = 0;
      }
                                                      
      _isLoading = false;                             
      notifyListeners(); // إخطار المستمعين بانتهاء التحميل وتحديث البيانات                     
    } catch (e) {
      // 3. معالجة الأخطاء                            
      _isLoading = false;
      _availableOffers = [];                          
      _selectedOffer = null;                          
      _currentQuantity = 0;
      if (kDebugMode) {
        print('Error fetching offers: $e');
      }
      notifyListeners(); // إخطار المستمعين بوجود خطأ                                               
    }
  }
                                                
  // 💡 دالة لتغيير العرض المختار
  void selectOffer(OfferModel offer) {
    _selectedOffer = offer;                         
    // تحديث الكمية الأولية عند اختيار عرض جديد     
    _currentQuantity = offer.stock >= (offer.minQty ?? 1)                                               
      ? (offer.minQty ?? 1)
      : 0;
    notifyListeners();
  }

  // 💡 دالة لتغيير الكمية                        
  void updateQuantity(int newQty) {
    _currentQuantity = newQty;                      
    notifyListeners();
  }
}                                               
