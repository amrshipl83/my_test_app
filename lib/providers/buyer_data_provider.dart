// lib/providers/buyer_data_provider.dart       
import 'package:flutter/material.dart';         
import 'package:cloud_firestore/cloud_firestore.dart';                                          
// ⭐️ استيراد النموذج الذي نحتاجه لحالة المستخدم المسجل ⭐️                                      
import 'package:my_test_app/models/logged_user.dart';                                                                                           

// ---------------------------------------------------------------------                        
// تعريفات النماذج (Models)                     
// ---------------------------------------------------------------------                        
class Category {                                                                                  
  final String id;
  final String name;                            
  final String imageUrl;                          
  Category({required this.id, required this.name, required this.imageUrl});                     
}                                                                                               

class BannerItem {                              
  final String id;                                                                                
  final String name;                                                                              
  final String imageUrl;                                                                                                                          
  final String? link;                                                                           
  
  BannerItem({required this.id, required this.name, required this.imageUrl, this.link});
}                                                                                                                                                                                               

// ---------------------------------------------------------------------                        
// Buyer Data Provider                          
// ---------------------------------------------------------------------                                                                        
class BuyerDataProvider with ChangeNotifier {                                                                                                                                                     
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;                                                                                                                                                                                                                                
  // ⭐️ المتغيرات الخاصة (Private Fields) ⭐️                                                      
  String _userName = 'مرحباً بك!';                                                                 
  LoggedInUser? _loggedInUser;                                                                                                                    
  // ⭐️⭐️ إضافة متغير الدور لحل خطأ 'userRole'  ⭐️⭐️                                              
  String _userRole = 'buyer';                                                                     
  bool _deliveryIsActive = false;                                                                 
  int _newOrdersCount = 0;                                                                                                                        
  int _cartCount = 0;                                                                             
  bool _ordersChanged = false;                                                                                                                    
  List<Category> _categories = [];                
  List<BannerItem> _banners = [];                                                                                                                 
  bool _isLoading = false;                                                                        
  String? _errorMessage;                                                                                                                                                                          
  
  // ⭐️ متغيرات حالة ظهور روابط الدليفري - تم تعديل الأسماء لتطابق الاستدعاء في buyer_home_screen.dart ⭐️                     
  bool _deliverySettingsAvailable = false; // 🛠️ تم التعديل من _showDeliverySettingsLink
  bool _deliveryPricesAvailable = false;   // 🛠️ تم التعديل من _showDeliveryPricesLink
                                                                                                                                                                                                           
  // ⭐️ Getters للسماح للـ Widgets بالوصول إلى الحالة ⭐️                                          
  String get userName => _userName;                                                               
  LoggedInUser? get loggedInUser => _loggedInUser;                                                                                                                                                
  // ⭐️⭐️ Getter الدور لحل خطأ 'userRole' ⭐️⭐️
  String get userRole => _userRole;                                                               
  bool get deliveryIsActive => _deliveryIsActive;                                                                                                 
  int get newOrdersCount => _newOrdersCount;                                                                                                      
  int get cartCount => _cartCount;                                                                
  bool get ordersChanged => _ordersChanged;                                                                                                       
  List<Category> get categories => _categories;   
  List<BannerItem> get banners => _banners;                                                                                                       
  bool get isLoading => _isLoading;               
  String? get errorMessage => _errorMessage;                                                                                                                                                                                                      
  
  // ⭐️ Getters لروابط الدليفري - تم تعديل الأسماء ⭐️                                                                
  bool get deliverySettingsAvailable => _deliverySettingsAvailable; // 🛠️ تم التعديل
  bool get deliveryPricesAvailable => _deliveryPricesAvailable;     // 🛠️ تم التعديل
                                                                                                                                                                                                                    
  // ⭐️ دالة التهيئة والتحميل الرئيسية ⭐️                                                                                                         
  Future<void> initializeData(String? currentUserId, String? currentDealerId, String? fullName) async {                                                                                         
    _isLoading = true;                                                                                                                              
    _errorMessage = null;                                                                                                                                                                                                                           
    // ⭐️⭐️ تعيين قيمة لـ _loggedInUser والـ userName ⭐️⭐️                                                                                          
    if (currentUserId != null && fullName != null) {                                                                                                  
      _loggedInUser = LoggedInUser(id: currentUserId, fullname: fullName, role: _userRole); // استخدام _userRole                                      
      _userName = 'أهلاً بك، $fullName!';                                                            
    } else {                                                                                          
      _loggedInUser = null;                                                                           
      _userName = 'مرحباً بك!';                      
    }                                                                                                                                               
    notifyListeners();                                                                                                                                                                              
    // تشغيل جميع وظائف جلب الحالة بناءً على منطق HTML/JS الأصلي                                                                                     
    _updateCartCountFromLocal();                                                                    
    await _checkDeliveryStatusAndDisplayIcons(currentDealerId);                                                                                     
    await _updateNewDealerOrdersCount(currentDealerId);                                                                                             
    await _monitorUserOrdersStatusChanges(currentUserId);                                                                                           
    await _loadCategoriesAndBanners();                                                                                                              
    _isLoading = false;                             
    notifyListeners();                            
  }                                                                                                                                                                                               

  // 🛠️ ---------------------------------------------                                              
  // 🛠️ الدوال المساعدة (مطابقة لمنطق الـ HTML/JS)                                                                                                                                                 
  // 🛠️ ---------------------------------------------                                                                                                                                                                                                                                                                                              
  // 🛠️ محاكاة لوظيفة updateCartCount              
  void _updateCartCountFromLocal() {                
    _cartCount = 3;                                                                                                                               
  }                                                                                                                                                                                                                                               
  
  // 🛠️ دالة checkDeliveryStatusAndDisplayIcons - تم تحديث استخدام المتغيرات هنا (مطابقة لمنطق HTML/JS)                                                                                                                             
  Future<void> _checkDeliveryStatusAndDisplayIcons(String? currentDealerId) async {                                                                                                                 
    // 🛠️ استخدام الأسماء الجديدة
    _deliverySettingsAvailable = false;                                                                                                              
    _deliveryPricesAvailable = false;                                                                                                                
    _deliveryIsActive = false;                                                                                                                                                                  
    
    if (currentDealerId == null || currentDealerId.isEmpty) { return; }                                                                                                                                                                             
    try {                                                                                                                                             
      final approvedQ = await _firestore.collection('deliverySupermarkets')                                                                                                                               
          .where("ownerId", isEqualTo: currentDealerId).get();                                                                                                                                                                                                                                                                                        
      if (approvedQ.docs.isNotEmpty) {                                                                                                                  
        final docData = approvedQ.docs[0].data();                                                                                                                                                       
        if (docData['isActive'] == true) {                                                                                                                
          _deliveryPricesAvailable = true; // 🛠️ تم التعديل 
          _deliveryIsActive = true;                                                                       
          return;                                       
        } else {                                                                                                                                          
          _deliveryIsActive = false;                                                                      
          return;                                       
        }                                                                                                                                             
      }                                                                                         
                                                      
      final pendingQ = await _firestore.collection('pendingSupermarkets')                                                                                                                                 
          .where("ownerId", isEqualTo: currentDealerId).get();                                                                                                                                        
      if (!pendingQ.docs.isEmpty) {                     
        _deliveryIsActive = false;                                                                                                                      
        return;                                                                                       
      }                                                                                                                                                                                                                                               
      _deliverySettingsAvailable = true; // 🛠️ تم التعديل
      _deliveryIsActive = false;                                                                                                                                                                    
    } catch (e) {                                                                                                                                     
      print('Delivery Status Error: $e');                                                       
      _deliveryIsActive = false;                                                                                                                    
    }                                                                                                                                               
    notifyListeners();                                                                                                                            
  }                                                                                                                                                                                                                                               
  
  // 🛠️ دالة updateNewDealerOrdersCount (مطابقة لمنطق HTML/JS)                                                                                                                                     
  Future<void> _updateNewDealerOrdersCount(String? currentDealerId) async {                                                                     
    if (currentDealerId == null || currentDealerId.isEmpty || !_deliveryIsActive) {                   
      _newOrdersCount = 0;                            
      notifyListeners();                                                                              
      return;                                                                                                                                       
    }                                                                                                                                               
    try {                                             
      final ordersQ = await _firestore.collection('consumerorders')                                                                                                                                       
          .where("supermarketId", isEqualTo: currentDealerId)                                                                                                                                             
          .where("status", isEqualTo: "new-order").get();                                                                                                                                                                                             
      _newOrdersCount = ordersQ.docs.length;        
    } catch (e) {                                                                                                                                     
      print('New Orders Count Error: $e');                                                                                                            
      _newOrdersCount = 0;                          
    }                                                                                                                                               
    notifyListeners();                            
  }                                                                                                                                                                                                                                             
  
  // 🛠️ دالة monitorUserOrdersStatusChanges (تصحيح أخطاء الاستعلام)                                                                                
  Future<void> _monitorUserOrdersStatusChanges(String? currentUserId) async {                                                                   
    if (currentUserId == null || currentUserId.isEmpty) { return; }                                                                                                                                                                                 
    try {                                                                                                                                             
      final querySnapshot = await _firestore.collection('consumerorders')                                                                                 
          .where("userId", isEqualTo: currentUserId)
          .orderBy("orderDate", descending: true)                                                                                                         
          .get();                                     
      _ordersChanged = true;                                                                                                                                                                        
    } catch (e) {                                     
      print('Monitor Orders Error: $e');                                                                                                              
      _ordersChanged = false;                                                                   
    }                                                                                                                                               
    notifyListeners();                                                                                                                            
  }                                                                                                                                               
  
  // 🛠️ دالة loadCategoriesAndBanners (جلب البيانات الرئيسية)                                                                                                                                      
  Future<void> _loadCategoriesAndBanners() async {                                                                                                                                                  
    try {                                             
      // 1. جلب الأقسام (mainCategory)                                                                                                                
      final categoriesQuery = _firestore
          .collection('mainCategory')                     
          .where('status', isEqualTo: 'active')           
          .orderBy('order', descending: false);                                                                                                       
      final categoriesSnapshot = await categoriesQuery.get();                                                                                                                                         
      _categories = categoriesSnapshot.docs.map((doc) {                                                 
        final data = doc.data();                                                                                                                        
        return Category(                                                                        
          id: doc.id,                                                                           
          name: data['name'] ?? 'قسم غير مسمى',                                                                                                           
          imageUrl: data['imageUrl'] ?? '',                                                                                                             
        );
      }).toList();                                                                                                                                                                                                                                                     
      // 2. جلب الإعلانات (retailerBanners)                                                                                                           
      final bannersQuery = _firestore                                                                                                                     
          .collection('retailerBanners')                                                                                                                  
          .where('status', isEqualTo: 'active')           
          .orderBy('order', descending: false);                                                                                                       
      final bannersSnapshot = await bannersQuery.get();                                                                                                                                               
      _banners = bannersSnapshot.docs.map((doc) {                                                                                                                                                       
        final data = doc.data();
        return BannerItem(                                                                                
          id: doc.id,                                                                                                                                     
          name: data['name'] ?? 'إعلان',                                                        
          imageUrl: data['imageUrl'] ?? '',                                                     
          link: data['link'],                                                                                                                           
        );                                                                                      
      }).toList();                                                                                                                                                                                  
    } catch (e) {                                                                                                                                     
      _errorMessage = 'فشل في تحميل البيانات: $e';                                                                                                                                                    
      _categories = [];                                                                               
      _banners = [];                                                                                                                                  
      print('Firebase Load Error: $e');                                                                                                             
    }                                                                                           
    notifyListeners();                                                                                                                            
  }                                             
}
