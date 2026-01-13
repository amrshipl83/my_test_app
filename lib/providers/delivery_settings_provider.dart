// lib/providers/delivery_settings_provider.dart

import 'package:flutter/material.dart';         
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/delivery_settings_model.dart';
import 'buyer_data_provider.dart'; 
import 'dart:async'; // مطلوب للـ Timer

// نموذج بيانات التاجر من مجموعة users    
class DealerProfile {                             
  final String name;                              
  final String address;
  final LocationModel? location;                  
  final String phone;
                                                  
  DealerProfile({required this.name, required this.address, this.location, required this.phone});                                               
}
                                                
class DeliverySettingsProvider with ChangeNotifier {                                              
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BuyerDataProvider _buyerData;                                                             
  
  late final String _currentDealerId;             
  late String _currentDealerOriginalPhone;                                                                                                  
  
  static const DELIVERY_COLLECTION = 'deliverySupermarkets';
  static const USERS_COLLECTION = 'users';                                                        

  bool _isLoading = false;
  String? _message;                               
  bool _isSuccess = true;
  Timer? _messageTimer; // تايمر لإخفاء الرسائل تلقائياً                                                                         

  DealerProfile? _dealerProfile;                  
  DeliverySettingsModel? _settings;
                                                  
  bool _deliveryActive = false;                   
  String _deliveryHours = '';                     
  String _whatsappNumber = '';                    
  String _deliveryPhone = '';                     
  String _deliveryFee = '0.0';
  String _minimumOrderValue = '0.0';
  String _descriptionForDelivery = '';                                                            

  // Getters                                      
  bool get isLoading => _isLoading;
  String? get message => _message;                
  bool get isSuccess => _isSuccess;               
  DealerProfile? get dealerProfile => _dealerProfile;                                             
  DeliverySettingsModel? get settings => _settings;                                                                                               
  bool get deliveryActive => _deliveryActive;
  String get deliveryHours => _deliveryHours;     
  String get whatsappNumber => _whatsappNumber;   
  String get deliveryPhone => _deliveryPhone;     
  String get deliveryFee => _deliveryFee;
  String get minimumOrderValue => _minimumOrderValue;                                             
  String get descriptionForDelivery => _descriptionForDelivery;
                                                  
  DeliverySettingsProvider(this._buyerData) {       
    _currentDealerId = _buyerData.loggedInUser?.id ?? '';
    _currentDealerOriginalPhone = _buyerData.loggedInUser?.phone ?? '';                         
    loadDeliveryData();                           
  }                                                                                               

  // ------------------------------------
  // وظائف إدارة الحالة (محسنة)
  // ------------------------------------
  void showNotification(String msg, bool success) {                                                 
    _message = msg;                                 
    _isSuccess = success;
    notifyListeners();                            

    // 🟢 ميزة الاختفاء التلقائي الاحترافي بعد 3 ثوانٍ
    _messageTimer?.cancel(); 
    _messageTimer = Timer(const Duration(seconds: 3), () {
      _message = null;
      notifyListeners();
    });
  }                                               

  void clearNotification() {                        
    _message = null;
    _messageTimer?.cancel();
    notifyListeners();                            
  }                                                                                               

  void setIsLoading(bool value) {
    _isLoading = value;
    notifyListeners();                            
  }                                                                                               

  void setDeliveryActive(bool value) {              
    _deliveryActive = value;
    notifyListeners();                            
  }                                                                                               

  // ------------------------------------         
  // وظائف تحميل البيانات (معدلة لمنع الخطأ الوهمي)
  // ------------------------------------       
  Future<void> loadDeliveryData() async {           
    setIsLoading(true);                             
    _message = null; // بدء التحميل بصمت بدون رسائل قديمة
    
    if (_currentDealerId.isEmpty) {                    
        setIsLoading(false);                            
        return;                                      
    }                                                                                                                                               
    try {                                               
        // 1. جلب بيانات التاجر الأساسية
        final dealerDocSnap = await _firestore.collection(USERS_COLLECTION).doc(_currentDealerId).get();                                                
        if (dealerDocSnap.exists) {
            final data = dealerDocSnap.data()!;                                                             
            LocationModel? locationModel;                   
            if (data['location'] is Map && data['location']!['lat'] != null) {                                
                locationModel = LocationModel(
                    lat: (data['location']['lat'] as num).toDouble(),
                    lng: (data['location']['lng'] as num).toDouble(),                                             
                );                                            
            }
                                                            
            _dealerProfile = DealerProfile(
                name: data['fullname'] ?? data['name'] ?? 'تاجر معتمد',                                          
                address: data['address'] ?? 'العنوان المسجل',                                                        
                location: locationModel,                        
                phone: data['phone'] ?? '' 
            );                                                                                              
            _currentDealerOriginalPhone = _dealerProfile!.phone;                                                                                        
        } 
        
        // 2. جلب إعدادات الدليفري الفعلية
        final deliveryDocSnap = await _firestore.collection(DELIVERY_COLLECTION).doc(_currentDealerId).get();                                   
        
        if (deliveryDocSnap.exists) {                                                                       
            _settings = DeliverySettingsModel.fromFirestore(deliveryDocSnap); 
            
            _deliveryActive = _settings!.deliveryActive;                                                    
            _deliveryHours = _settings!.deliveryHours;                                                      
            _whatsappNumber = _settings!.whatsappNumber;                                        
            _deliveryPhone = (_settings!.deliveryContactPhone == _currentDealerOriginalPhone) ? '' : _settings!.deliveryContactPhone;                                                                       
            _deliveryFee = _settings!.deliveryFee.toStringAsFixed(2);                           
            _minimumOrderValue = _settings!.minimumOrderValue.toStringAsFixed(2);                                                                           
            _descriptionForDelivery = _settings!.descriptionForDelivery;
        } else {                                            
            // إذا لم يتم العثور على مستند الدليفري (تاجر جديد لم يضبط إعداداته بعد)
            _settings = DeliverySettingsModel(ownerId: _currentDealerId); 
            _deliveryActive = false;                    
            _message = null; // نضمن عدم وجود رسالة "حدث خطأ"
        }                                                    
    } catch (e) {                                       
        // 🔴 لا يظهر هنا إلا إذا حدث خطأ تقني حقيقي (إنترنت أو صلاحيات)
        debugPrint('Error loading delivery data: $e');
    }                                                                                               
    setIsLoading(false);                          
  }
  
  // ------------------------------------       
  // وظائف الإرسال (Submit)                       
  // ------------------------------------         
  Future<void> submitSettings({                                                                     
    required String hours,
    required String whatsapp,                                                                       
    required String phone,
    required String fee,
    required String minOrder,                   
    required String description,
  }) async {                                    
    setIsLoading(true);                             
    clearNotification();
                                                                                                    
    if (_dealerProfile?.location == null) {           
      showNotification('موقع السوبر ماركت غير متوفر في ملفك الشخصي.', false);
      setIsLoading(false);                            
      return;                                                                                       
    }
                                                    
    try {
        final double parsedFee = double.tryParse(fee) ?? 0.0;
        final double parsedMinOrder = double.tryParse(minOrder) ?? 0.0;                         
        final contactPhone = phone.isEmpty ? _currentDealerOriginalPhone : phone;               
                                                        
        final DeliverySettingsModel dataToSave = DeliverySettingsModel(
            ownerId: _currentDealerId,
            supermarketName: _dealerProfile!.name,                                                                                                          
            address: _dealerProfile!.address,
            location: _dealerProfile!.location,
            deliveryActive: _deliveryActive,
            deliveryHours: hours,
            whatsappNumber: whatsapp,                                                                       
            deliveryContactPhone: contactPhone,             
            deliveryFee: parsedFee,
            minimumOrderValue: parsedMinOrder,
            descriptionForDelivery: description,        
        );                                                                                              
        
        final deliveryDocRef = _firestore.collection(DELIVERY_COLLECTION).doc(_currentDealerId);
                                                
        if (!_deliveryActive) {                             
            await deliveryDocRef.update({                       
                'deliveryActive': false,
                'lastUpdated': FieldValue.serverTimestamp()                                                 
            });                                             
            showNotification('تم إيقاف الخدمة بنجاح، لن يراك العملاء حالياً.', true);                                    
        } else {                                            
            await deliveryDocRef.set(dataToSave.toFirestore(), SetOptions(merge: true));        
            showNotification('تم حفظ وتفعيل إعدادات الدليفري بنجاح!', true);                                                                            
        }
                                                        
        // إعادة التحميل بصمت لتحديث الواجهة
        await loadDeliveryData();

    } catch (e) {                               
        showNotification('عذراً، فشل الحفظ. تأكد من اتصالك بالإنترنت.', false);                   
        debugPrint('Error submitting delivery settings: $e');
    }
    setIsLoading(false);                          
  }

  @override
  void dispose() {
    _messageTimer?.cancel(); // تنظيف التايمر عند إغلاق الشاشة
    super.dispose();
  }                                             
}
