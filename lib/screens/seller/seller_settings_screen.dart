// lib/screens/seller/seller_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ✅ المكتبات المستقرة
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ----------------------------------------------------------------------
// 0. الثوابت
// ----------------------------------------------------------------------
const Color primaryColor = Color(0xff28a745); // اللون الأساسي الأخضر

// 🗺️ رابط بلاطات CartoDB Positron (الخلفية الفاتحة)
const String TILE_URL = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'; 
const List<String> TILE_SUBDOMAINS = ['a', 'b', 'c', 'd'];

// قائمة أنواع الأعمال التجارية (مطابقة لـ HTML/JS)
const List<DropdownMenuItem<String>> businessTypeItems = [
  DropdownMenuItem(value: 'electronics', child: Text('إلكترونيات')),
  DropdownMenuItem(value: 'fashion', child: Text('مواد غذائية')),
  DropdownMenuItem(value: 'food', child: Text('أطعمة ومطاعم')),
  DropdownMenuItem(value: 'services', child: Text('خدمات')),
  DropdownMenuItem(value: 'other', child: Text('أخرى')),
];

// قائمة صلاحيات المستخدم الفرعي (مطابقة لـ HTML/JS)
const List<DropdownMenuItem<String>> subUserRoleItems = [
  DropdownMenuItem(value: 'full', child: Text('صلاحية كاملة (كتابة وقراءة)')),
  DropdownMenuItem(value: 'read_only', child: Text('صلاحية عرض فقط (قراءة)')),
];

// ----------------------------------------------------------------------
// 1. نماذج البيانات (Models)
// ----------------------------------------------------------------------

class Branch {
  final String? address;
  final double? lat;
  final double? long;
  final String? createdAt;

  Branch({this.address, this.lat, this.long, this.createdAt});

  factory Branch.fromMap(Map<String, dynamic> map) {
    return Branch(
      address: map['address'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      long: (map['long'] as num?)?.toDouble(),
      createdAt: map['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'lat': lat,
      'long': long,
      'createdAt': createdAt,
    };
  }
}

class SubUser {
  final String? phone;
  final String? role;
  final String? addedAt;

  SubUser({this.phone, this.role, this.addedAt});

  factory SubUser.fromMap(Map<String, dynamic> map) {
    return SubUser(
      phone: map['phone'] as String?,
      role: map['role'] as String?,
      addedAt: map['addedAt'] as String?,
    );
  }
}

// ----------------------------------------------------------------------
// 2. الشاشة (Screen)
// ----------------------------------------------------------------------

class SellerSettingsScreen extends StatefulWidget {
  final String currentSellerId;

  const SellerSettingsScreen({super.key, required this.currentSellerId});

  @override
  State<SellerSettingsScreen> createState() => _SellerSettingsScreenState();
}

class _SellerSettingsScreenState extends State<SellerSettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;

  Map<String, dynamic> sellerDataCache = {};

  final _merchantNameController = TextEditingController();
  final _minOrderTotalController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _subUserPhoneController = TextEditingController();

  String? _selectedBusinessType;
  String _selectedSubUserRole = 'full';

  // حالة الخريطة لـ flutter_map
  final MapController _mapController = MapController();
  LatLng? _branchLocation;
  String _branchLatLong = '0.0, 0.0';
  String _branchAddress = 'يرجى تحديد موقع الفرع على الخريطة.';                                           
  // لإدارة الماركر الحالي                             
  Marker? _currentMarker;
                                                       
  // ----------------------------------------------------------------------                                 
  // LIFECYCLE & DATA LOADING
  // ----------------------------------------------------------------------
  @override                                            
  void initState() {
    super.initState();                                   
    _loadSellerData();
  }                                                  
  
  @override                                            
  void dispose() {
    _merchantNameController.dispose();                   
    _minOrderTotalController.dispose();
    _deliveryFeeController.dispose();                    
    _subUserPhoneController.dispose();
    super.dispose();                                   
  }

  Future<void> _loadSellerData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final sellerRef = _firestore.collection("sellers").doc(widget.currentSellerId);
      final sellerSnap = await sellerRef.get();

      if (sellerSnap.exists) {
        sellerDataCache = sellerSnap.data()!;

        _merchantNameController.text = sellerDataCache['merchantName'] ?? '';
        _minOrderTotalController.text = (sellerDataCache['minOrderTotal'] as num? ?? 0.0).toString();
        _deliveryFeeController.text = (sellerDataCache['deliveryFee'] as num? ?? 0.0).toString();

        final loadedBusinessType = sellerDataCache['businessType'];
        if (loadedBusinessType != null && businessTypeItems.any((item) => item.value == loadedBusinessType)) {
          _selectedBusinessType = loadedBusinessType;        
        } else {
          _selectedBusinessType = null;
        }                                            
        final branches = (sellerDataCache['branches'] as List<dynamic>?);
        if (branches != null && branches.isNotEmpty) {
          final firstBranchMap = branches.first as Map<String, dynamic>;
          final firstBranch = Branch.fromMap(firstBranchMap);

          if (firstBranch.lat != null && firstBranch.long != null) {
            _branchLocation = LatLng(firstBranch.lat!, firstBranch.long!);
            _updateBranchLocation(firstBranch.lat!, firstBranch.long!, firstBranch.address);
          }
        }
      } else {
        _showSnackBar("لم يتم العثور على بيانات البائع.", isError: true);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء تحميل البيانات: $e", isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ----------------------------------------------------------------------
  // MAP LOGIC (Flutter Map - CartoDB Tiles)
  // ----------------------------------------------------------------------

  void _addMarker(double lat, double lng) async {
    setState(() {
      _currentMarker = Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        builder: (context) => const Icon(
          Icons.location_pin,
          color: primaryColor, // استخدام اللون الأساسي
          size: 40,
        ),
      );
      // 2. تحديث بيانات الموقع
      _updateBranchLocation(lat, lng);
    });

    // 3. تحريك الكاميرا (إذا تم تحميل الخريطة)
    _mapController.move(LatLng(lat, lng), 14.0);
  }

  void _updateBranchLocation(double lat, double lng, [String? address]) {
    setState(() {
      _branchLatLong = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
      _branchAddress = address ?? 'تم تحديد الإحداثيات: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}.';
      _branchLocation = LatLng(lat, lng);
      // يتم إنشاء الماركر وتحديثه عند تعيين الموقع الأولي من Firebase
      if (_currentMarker == null && lat != 0.0 && lng != 0.0) {
         _currentMarker = Marker(
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          builder: (context) => const Icon(
            Icons.location_pin,
            color: primaryColor,
            size: 40,
          ),
        );
      }
    });
  }

  // ----------------------------------------------------------------------
  // ACTION HANDLERS
  // ----------------------------------------------------------------------

  Future<void> _updateBusinessData() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    final updates = <String, dynamic>{};
    final newMerchantName = _merchantNameController.text.trim();
    final newBusinessType = _selectedBusinessType;

    if (newMerchantName.isNotEmpty && newMerchantName != (sellerDataCache['merchantName'] ?? '')) {
      updates['merchantName'] = newMerchantName;
    }
    if (newBusinessType != null && newBusinessType != (sellerDataCache['businessType'] ?? '')) {
      updates['businessType'] = newBusinessType;
    }

    if (updates.isEmpty) {
      _showSnackBar("لم يتم إدخال أي تغييرات جديدة للحفظ.", isError: true);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final sellerRef = _firestore.collection("sellers").doc(widget.currentSellerId);
      await sellerRef.update(updates);
      _showSnackBar("✅ تم تحديث بيانات العمل التجاري بنجاح!");
      await _loadSellerData();
    } catch (e) {
      _showSnackBar("❌ حدث خطأ أثناء تحديث البيانات: $e", isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderSettings() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    final minOrderString = _minOrderTotalController.text.trim();
    final deliveryFeeString = _deliveryFeeController.text.trim();

    final newMinOrderTotal = double.tryParse(minOrderString);
    final newDeliveryFee = double.tryParse(deliveryFeeString);

    if (newMinOrderTotal == null || newMinOrderTotal < 0 || newDeliveryFee == null || newDeliveryFee < 0) {
      _showSnackBar("الرجاء إدخال قيم صحيحة وموجبة للحد الأدنى للطلب ومصاريف الشحن.", isError: true);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final updates = <String, dynamic>{};
    updates['minOrderTotal'] = newMinOrderTotal;
    updates['deliveryFee'] = newDeliveryFee;

    try {
      final sellerRef = _firestore.collection("sellers").doc(widget.currentSellerId);
      await sellerRef.update(updates);
      _showSnackBar("✅ تم تحديث إعدادات الطلبات ومصاريف الشحن بنجاح!");
      await _loadSellerData();
    } catch (e) {
      _showSnackBar("❌ حدث خطأ أثناء تحديث الإعدادات: $e", isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addBranch() async {
    if (_isLoading) return;
    if (_branchLocation == null || (_branchLocation!.latitude == 0.0 && _branchLocation!.longitude == 0.0)) {
      _showSnackBar("يرجى تحديد موقع الفرع على الخريطة أولاً (عبر النقر).", isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // استخدام إحداثيات _branchLocation مباشرة
    final newBranch = Branch(
      address: _branchAddress,
      lat: _branchLocation!.latitude,
      long: _branchLocation!.longitude,
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      final sellerRef = _firestore.collection("sellers").doc(widget.currentSellerId);

      if (sellerDataCache.containsKey('branches')) {
        await sellerRef.update({
          'branches': FieldValue.arrayUnion([newBranch.toMap()])
        });
      } else {
        // في حالة عدم وجود حقل 'branches' من قبل
        await sellerRef.set({
          'branches': [newBranch.toMap()]
        }, SetOptions(merge: true));
      }

      _showSnackBar("✅ تم إضافة فرع جديد بنجاح!");
      await _loadSellerData();

      // حذف الماركر المؤقت وتصفير الموقع
      setState(() {
         _currentMarker = null;
        _updateBranchLocation(0.0, 0.0, 'يرجى تحديد موقع الفرع على الخريطة.');
      });


    } catch (e) {
      _showSnackBar("❌ فشل إضافة الفرع: $e", isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addSubUser() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    final phone = _subUserPhoneController.text.trim();
    final role = _selectedSubUserRole;

    if (phone.isEmpty) {
      _showSnackBar("الرجاء إدخال رقم هاتف المستخدم الفرعي.", isError: true);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final subUsers = (sellerDataCache['subUsers'] as List<dynamic>?)
        ?.map((u) => SubUser.fromMap(u as Map<String, dynamic>))
        .toList() ?? [];

    final isDuplicate = subUsers.any((u) => u.phone == phone);
    if (isDuplicate) {
      _showSnackBar("هذا المستخدم الفرعي (رقم الهاتف) مسجل بالفعل.", isError: true);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final newSubUser = {
        'phone': phone,
        'role': role,
        'addedAt': DateTime.now().toIso8601String()
      };

      final sellerRef = _firestore.collection("sellers").doc(widget.currentSellerId);
      await sellerRef.update({
        'subUsers': FieldValue.arrayUnion([newSubUser])
      });

      _showSnackBar("✅ تم تسجيل المستخدم الفرعي $phone بنجاح!");
      await _loadSellerData();
      _subUserPhoneController.clear();

    } catch (e) {
      _showSnackBar("❌ حدث خطأ أثناء إضافة المستخدم الفرعي: $e", isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تحذير هام!'),
            content: const Text('أنت على وشك تعطيل حسابك بشكل دائم. هل أنت متأكد من المتابعة؟'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('تأكيد التعطيل', style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final sellerRef = _firestore.collection("sellers").doc(widget.currentSellerId);
      await sellerRef.update({
        'status': "inactive",
        'inactiveAt': DateTime.now().toIso8601String()
      });

      _showSnackBar("تم تعطيل حسابك بنجاح. سيتم تسجيل خروجك الآن.", isError: true);

      await Future.delayed(const Duration(seconds: 3));
    } catch (e) {
      _showSnackBar("❌ حدث خطأ أثناء محاولة تعطيل الحساب: $e", isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: isError ? Colors.red : primaryColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // UI BUILDER
  // ----------------------------------------------------------------------

  Widget _buildBranchList(List<Branch> branches) {
    if (branches.isEmpty) {
      return const Text(
        'لا يوجد فروع إضافية مسجلة حالياً.',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: branches.asMap().entries.map((entry) {
        final index = entry.key;
        final branch = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'فرع ${index + 1}: ${branch.address ?? 'عنوان غير متوفر'}',
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '(${branch.lat?.toStringAsFixed(4) ?? '..'}, ${branch.long?.toStringAsFixed(4) ?? '..'})',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubUserList(List<SubUser> subUsers) {
    if (subUsers.isEmpty) {
      return const Text(
        'لا يوجد مستخدمون فرعيون مسجلون حالياً.',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subUsers.map((user) {
        final roleText = user.role == 'full' ? 'صلاحية كاملة' : 'عرض فقط';
        final roleColor = user.role == 'full' ? Colors.white : Colors.black87;
        final roleBg = user.role == 'full' ? primaryColor : Colors.amber.shade400;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user.phone ?? 'رقم غير متوفر',
                style: const TextStyle(fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: roleBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  roleText,
                  style: TextStyle(
                    fontSize: 12,
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branches = (sellerDataCache['branches'] as List<dynamic>?)
            ?.map((b) => Branch.fromMap(b as Map<String, dynamic>))
            .toList() ??
        [];

    final subUsers = (sellerDataCache['subUsers'] as List<dynamic>?)
            ?.map((u) => SubUser.fromMap(u as Map<String, dynamic>))
            .toList() ??
        [];

    final initialCenter = _initialCenter();
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الحساب'),
        backgroundColor: primaryColor,
        automaticallyImplyLeading: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('البيانات الأساسية (غير قابلة للتعديل)'),
                  _buildSettingItem('الاسم الكامل للتاجر (صاحب الحساب):', sellerDataCache['fullname']),
                  _buildSettingItem('البريد الإلكتروني الأساسي:', sellerDataCache['email']),
                  _buildSettingItem('رقم الهاتف الأساسي:', sellerDataCache['phone']),
                  _buildSettingItem('العنوان الأساسي المسجل:', sellerDataCache['fullAddress']),

                  _buildSectionTitle('إعدادات العمل التجاري القابلة للتعديل'),
                  _buildEditableSetting(
                    label: 'اسم النشاط التجاري:',
                    input: TextField(
                      controller: _merchantNameController,
                      decoration: const InputDecoration(hintText: 'أدخل اسم متجرك/شركتك'),
                    ),
                  ),
                  _buildEditableSetting(
                    label: 'نوع العمل التجاري:',
                    input: DropdownButtonFormField<String>(
                      value: _selectedBusinessType,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      hint: const Text('اختار نوع النشاط'),
                      items: businessTypeItems,
                      onChanged: (value) => setState(() => _selectedBusinessType = value),
                    ),
                  ),
                  _buildImageUploadSection(),

                  // زر تحديث بيانات العمل التجاري
                  ElevatedButton(
                    onPressed: _updateBusinessData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,                       
                      minimumSize: const Size(double.infinity, 50),                                                           
                    ),
                    child: const Text('تحديث بيانات العمل التجاري', style: TextStyle(color: Colors.white, fontSize: 16)),                                                        
                  ),
                  const SizedBox(height: 20),
                                                                       
                  _buildSectionTitle('إعدادات الطلبات والعمولة'),
                  _buildEditableSetting(                                 
                    label: 'الحد الأدنى للطلب (ج.م):',
                    input: TextField(
                      controller: _minOrderTotalController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),                                       
                      decoration: const InputDecoration(hintText: 'أدخل الحد الأدنى للطلب'),
                    ),
                  ),
                  _buildEditableSetting(
                    label: 'مصاريف الشحن الثابتة (ج.م):',
                    input: TextField(
                      controller: _deliveryFeeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'أدخل سعر الشحن الثيبت'),
                    ),
                  ),
                  _buildSettingItem('سعر عمولة أكسب (%):', '${sellerDataCache['commissionRate'] ?? 0}%'),

                  // زر تحديث إعدادات الطلبات
                  ElevatedButton(
                    onPressed: _updateOrderSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('تحديث إعدادات الطلبات والشحن', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  const SizedBox(height: 20),

                  _buildSectionTitle('إدارة فروع المتجر (إضافة فرع جديد)'),

                  // ✅ استخدام Map Container مع CartoDB Tiles (النمط الفاتح)
                  _buildMapContainer(initialCenter),
                  const SizedBox(height: 10),
                  _buildSettingItem('عنوان الفرع الجديد (المحدد على الخريطة):', _branchAddress),
                  _buildSettingItem('إحداثيات (Lat, Long):', _branchLatLong),

                  // زر إضافة فرع جديد
                  ElevatedButton(
                    onPressed: _addBranch,
                    style: ElevatedButton.styleFrom(                       
                      backgroundColor: const Color(0xff007bff), // لون أزرق للزر الثانوي
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('إضافة فرع جديد', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),                                                   
                  const SizedBox(height: 10),

                  const Text('الفروع المسجلة حالياً:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  _buildBranchList(branches),
                  const SizedBox(height: 20),
                                                                       
                  _buildSectionTitle('إدارة المستخدمين الفرعيين (Sub-Users)'),
                  _buildEditableSetting(
                    label: 'رقم هاتف المستخدم الجديد (للمصادقة):',
                    input: TextField(
                      controller: _subUserPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: '+201XXXXXXXXX'),
                    ),                                                 
                  ),
                  _buildEditableSetting(
                    label: 'صلاحية المستخدم:',
                    input: DropdownButtonFormField<String>(
                      value: _selectedSubUserRole,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: subUserRoleItems,       
                      onChanged: (value) => setState(() => _selectedSubUserRole = value ?? 'full'),
                    ),
                  ),
                                                                       // زر إضافة مستخدم فرعي                                                                                   
                  ElevatedButton(
                    onPressed: _addSubUser,
                    style: ElevatedButton.styleFrom(                       
                      backgroundColor: const Color(0xff007bff),                                           
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('إضافة مستخدم فرعي', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  const SizedBox(height: 10),

                  const Text('المستخدمون الحاليون:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  _buildSubUserList(subUsers),
                  const SizedBox(height: 40),

                  _buildSectionTitle('منطقة الخطر', color: Colors.red),
                  Center(
                    child: ElevatedButton(                                 
                      onPressed: _deleteAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, 
                        minimumSize: const Size(double.infinity, 50),                                                           
                      ),
                      child: const Text('تعطيل حسابي', style: TextStyle(color: Colors.white, fontSize: 16)),                                                                       
                    ),
                  ),                                                   
                  const SizedBox(height: 40),        
                ],                                                 
              ),
            ),                                           
    );
  }                                                  
  // ----------------------------------------------------------------------
  // HELPER WIDGETS
  // ----------------------------------------------------------------------
                                                       
  LatLng _initialCenter() {
    // إحداثيات افتراضية للقاهرة: 30.0333, 31.2357       
    final defaultPoint = LatLng(30.0333, 31.2357);
    return _branchLocation ?? defaultPoint;
  }

  Widget _buildSectionTitle(String title, {Color color = primaryColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15.0),                                                      
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );                                                 
  }

  Widget _buildSettingItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(value?.toString() ?? 'غير متاح', style: const TextStyle(fontSize: 16, color: Colors.black54)),
          const Divider(height: 10, color: Colors.black12),
        ],
      ),
    );
  }

  Widget _buildEditableSetting({required String label, required Widget input}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,        
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),                  
          const SizedBox(height: 8),
          input,
          const SizedBox(height: 4),                         
        ],
      ),                                                 
    );
  }                                                  
  
  Widget _buildImageUploadSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الشعار الحالي:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 8),
          if (sellerDataCache['merchantLogoUrl'] != null)
            Image.network(
              sellerDataCache['merchantLogoUrl'],                  
              width: 150,
              height: 150,
              fit: BoxFit.contain,                                 
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, size: 100, color: Colors.grey),
            ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              _showSnackBar("🚫 وظيفة اختيار الملف ورفعه (Cloudinary) غير مفعلة في هذا الكود.", isError: true);
            },
            icon: const Icon(Icons.upload_file, color: Colors.black87),                                               
            label: const Text('رفع شعار المتجر الجديد', style: TextStyle(color: Colors.black87)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,               
              elevation: 0,
            ),
          ),
          const Text(
            'سيتم تحديث الشعار فقط إذا اخترت ملفاً جديداً.',                                                            
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 2),
          ),
        ],
      ),
    );
  }

  // ✅ بناء Map Container باستخدام Flutter Map (CartoDB Tiles)
  Widget _buildMapContainer(LatLng initialCenter) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: initialCenter,
            zoom: 12.0,
            onTap: (tapPosition, point) {                          
              _addMarker(point.latitude, point.longitude); // إضافة ماركر عند النقر                                   
            },
          ),
          children: [                                            
            // 🛑 الطبقة هنا تستخدم بلاطات CartoDB Positron (الفاتح)
            TileLayer(                                             
              urlTemplate: TILE_URL,
              subdomains: TILE_SUBDOMAINS,
              userAgentPackageName: 'com.example.app',                                                                  
              maxZoom: 19, 
            ),
            MarkerLayer(                                           
              markers: _currentMarker == null ? [] : [_currentMarker!],
            ),
          ],
        ),
      ),
    );
  }
}
