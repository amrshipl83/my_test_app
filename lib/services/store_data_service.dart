// lib/services/store_data_service.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
// ❌ تم إزالة: import 'package:my_test_app/firebase.js.dart';

class StoreDataService with ChangeNotifier {
  // 💡 الوصول المباشر إلى قاعدة البيانات
  final FirebaseFirestore _db = FirebaseFirestore.instance; 

  // 1. حالة الشاشة والبيانات
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _loggedUser;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _banners = [];

  // حالة الدليفري والطلبات الجديدة
  bool _deliveryLinksVisible = false;
  bool _isDeliveryActive = false;
  int _newOrdersCount = 0;
  List<Map<String, dynamic>> _newDeliveryOrders = [];

  // حالة سلة المشتريات
  int _cartCount = 0;
  bool _hasOrderChanges = false;
  int _currentBannerIndex = 0;

  // 2. الواجهات العامة (Getters)
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get loggedUser => _loggedUser;
  
  List<Map<String, dynamic>> get categories => _categories;
  List<Map<String, dynamic>> get banners => _banners;
  
  bool get deliveryLinksVisible => _deliveryLinksVisible;
  bool get isDeliveryActive => _isDeliveryActive;
  int get newOrdersCount => _newOrdersCount;
  
  int get cartCount => _cartCount;
  bool get hasOrderChanges => _hasOrderChanges;
  int get currentBannerIndex => _currentBannerIndex;

  // 3. التهيئة - جلب كل البيانات عند بدء تشغيل الشاشة
  Future<void> initializeData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadUserData();
      
      await Future.wait([
        _loadCategories(),
        _loadRetailerBanners(),
        _checkDeliveryStatusAndDisplayIcons(),
        _updateNewDealerOrdersCount(),
        _updateCartCount(),
        _monitorUserOrdersStatusChanges(),
      ]);

    } catch (e) {
      _errorMessage = 'حدث خطأ حرج أثناء تهيئة البيانات.';
      debugPrint('Initialization Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      _startBannerAutoSlide();
    }
  }
  
  // 4. منطق جلب البيانات من Firebase (كما في كود الـ HTML)

  // 4.1 جلب الأقسام
  Future<void> _loadCategories() async {
    try {
      final q = _db.collection('mainCategory')
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false);
          
      final querySnapshot = await q.get();
      _categories = querySnapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      _errorMessage = 'خطأ في جلب الأقسام.';
      debugPrint('Error loading categories: $e');
    }
  }

  // 4.2 جلب البانرات
  Future<void> _loadRetailerBanners() async {
    try {
      final q = _db.collection('retailerBanners')
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false);
          
      final querySnapshot = await q.get();
      _banners = querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error loading banners: $e');
      _banners = [];
    }
  }
  
  // 4.3 التحقق من حالة الدليفري للتاجر (استخدام الحقول المحفوظة)
  Future<void> _checkDeliveryStatusAndDisplayIcons() async {
    _deliveryLinksVisible = false;
    _isDeliveryActive = false;
    
    final currentDealerId = _loggedUser?['id'];
    if (currentDealerId == null) return;
    
    // 💡 استخدام collectionConstants المحفوظة: deliverySupermarkets
    final deliverySupermarketsRef = _db.collection('deliverySupermarkets'); 
    
    try {
      // التحقق من حالة "Active" في 'deliverySupermarkets' باستخدام الحقل المحفوظ ownerId
      final approvedQuery = deliverySupermarketsRef
          .where("ownerId", isEqualTo: currentDealerId); 
          
      final approvedSnapshot = await approvedQuery.get();
      
      if (approvedSnapshot.docs.isNotEmpty) {
          final docData = approvedSnapshot.docs.first.data();
          if (docData['isActive'] == true) {
              _isDeliveryActive = true;
              _deliveryLinksVisible = true;
              return;
          }
      }
      
      // التحقق من حالة "Pending"
      final pendingQuery = _db.collection('pendingSupermarkets')
          .where("ownerId", isEqualTo: currentDealerId);
          
      final pendingSnapshot = await pendingQuery.get();
      
      if (pendingSnapshot.docs.isNotEmpty) {
          _deliveryLinksVisible = false;
          return;
      }
      
      // إذا لم يكن مُسجل أو قيد الانتظار، أظهر رابط التسجيل
      _deliveryLinksVisible = true;
      _isDeliveryActive = false;

    } catch (error) {
        debugPrint("Error checking delivery status: $error");
    }
  }

  // 4.4 تحديث عدد طلبات الدليفري الجديدة
  Future<void> _updateNewDealerOrdersCount() async {
    _newOrdersCount = 0;
    _newDeliveryOrders = [];
    final currentDealerId = _loggedUser?['id'];
    if (currentDealerId == null || !_isDeliveryActive) return;
    
    try {
      final ordersRef = _db.collection('consumerorders');
      final q = ordersRef
          .where("supermarketId", isEqualTo: currentDealerId)
          .where("status", isEqualTo: "new-order");
          
      final querySnapshot = await q.get();
      querySnapshot.docs.forEach((doc) {
        _newDeliveryOrders.add({'id': doc.id, ...doc.data()});
      });
      _newOrdersCount = _newDeliveryOrders.length;
    } catch (error) {
        debugPrint("Error updating new dealer orders count: $error");
    }
  }
  
  // 4.5 تحديث عدد عناصر السلة (مُحاكاة)
  Future<void> _updateCartCount() async {
    // يجب استبدال هذا بمنطق قراءة shared_preferences أو قاعدة البيانات
    _cartCount = 3; 
  }
  
  // 4.6 مراقبة تغييرات حالة طلبات المستخدم (مُحاكاة)
  Future<void> _monitorUserOrdersStatusChanges() async {
    // يجب استبدال هذا بمنطق مراقبة Stream Firebase
    _hasOrderChanges = true; 
  }

  // 5. منطق الـ UI والـ State
  
  void openOrdersModal(BuildContext context) {
    if (_newOrdersCount > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('طلبات دليفري جديدة', textAlign: TextAlign.right),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _newDeliveryOrders.length,
              itemBuilder: (context, index) {
                final order = _newDeliveryOrders[index];
                return ListTile(
                  title: Text('العميل: ${order['customerName'] ?? 'غير معروف'}', textAlign: TextAlign.right),
                  subtitle: Text('الإجمالي: ${order['finalAmount'] ?? 0} جنيه', textAlign: TextAlign.right),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/deliveryOrders', arguments: {
                  'ownerId': _loggedUser?['id'], 
                  'userName': _loggedUser?['fullname']
                });
              },
              child: const Text('عرض كل الطلبات'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد طلبات دليفري جديدة حاليًا.')),
      );
    }
    _newOrdersCount = 0;
    notifyListeners();
  }

  void setCurrentBannerIndex(int index) {
    _currentBannerIndex = index;
    notifyListeners();
  }
  
  void _startBannerAutoSlide() {
    // Placeholder for timer logic
  }
  
  Future<void> _loadUserData() async {
    // Placeholder for loading user data from localStorage/SharedPreferences
    _loggedUser = {
      'id': 'dealer-123',
      'fullname': 'أحمد التاجر',
      'role': 'seller',
    };
  }
}
