// lib/controllers/seller_dashboard_controller.dart (النسخة النهائية والمُصحَّحة)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_test_app/models/seller_dashboard_data.dart';
import 'package:my_test_app/screens/login_screen.dart';
// 🛠️ استيراد الموديل ومصدر البيانات الخاص بمناطق التوصيل
import 'package:my_test_app/models/delivery_area_model.dart';
import 'package:my_test_app/data_sources/delivery_area_data_source.dart';

class SellerDashboardController with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🛠️ تهيئة مصدر بيانات مناطق التوصيل
  final DeliveryAreaDataSource _deliveryAreaDataSource = DeliveryAreaDataSource();

  // حالة لوحة التحكم
  SellerDashboardData _data = SellerDashboardData.loading();

  // 🛠️ حالة مناطق التوصيل (Delivery Areas State)
  List<DeliveryAreaModel> _deliveryAreas = [];

  bool _isLoading = true;
  String? _errorMessage;
  String? _sellerName; // يُستخدم لتمرير الاسم إلى الموديل

  // حالة الوضع الليلي (Dark Mode)
  bool _isDarkMode = false;

  // الواجهات العامة (Getters)
  SellerDashboardData get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get welcomeMessage =>
      'مرحبًا بك يا ${_sellerName ?? 'بائع'} في لوحة تحكم البائع';
  bool get isDarkMode => _isDarkMode;
  // 🛠️ واجهة عامة لقائمة مناطق التوصيل
  List<DeliveryAreaModel> get deliveryAreas => _deliveryAreas;
  
  // 🟢 إضافة ID البائع كـ Getter (يُستخدم في SellerScreen لتمريره للشريط الجانبي)
  String get sellerId => _auth.currentUser?.uid ?? ''; 

  SellerDashboardController() {
    _loadDarkModePreference();
  }

  // --- منطق الوضع الليلي (Dark Mode) ---

  void _loadDarkModePreference() {
    // 💡 منطق تحميل تفضيلات الوضع الليلي
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  // ----------------------------------------------------------------------
  // --- منطق مناطق التوصيل (Delivery Areas Logic) ---
  // ----------------------------------------------------------------------

  // 🛠️ دالة جلب مناطق التوصيل (المتاحة)
  Future<void> fetchDeliveryAreas() async {
    _errorMessage = null;
    try {
      // 💡 منطق جلب جميع المناطق المتاحة (يجب أن يتم تنفيذه)
    } catch (e) {
      _errorMessage = 'خطأ في جلب مناطق التوصيل.';
      debugPrint('Error fetching delivery areas: $e');
    }
  }

  // 🛠️ دالة تحديث مناطق التوصيل
  Future<bool> updateDeliveryAreas(List<String> selectedAreaIds) async {
    if (_auth.currentUser == null) {
      _errorMessage = 'يجب تسجيل الدخول لتحديث مناطق التوصيل.';
      notifyListeners();
      return false;
    }

    final sellerId = _auth.currentUser!.uid;
    _errorMessage = null;
    bool success = false;

    try {
      final newAreas = selectedAreaIds.map((id) => DeliveryAreaModel(
        id: id,
        code: id,
        name: id,
      )).toList();

      await _deliveryAreaDataSource.updateAreas(sellerId, newAreas);
      _errorMessage = 'تم تحديث مناطق التوصيل بنجاح.';
      success = true;
    } on FirebaseException catch (e) {
      _errorMessage = 'خطأ في تحديث مناطق التوصيل: ${e.code}';
      debugPrint('Firebase Error: $e');
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع أثناء تحديث مناطق التوصيل.';
      debugPrint('General Error: $e');
    }

    notifyListeners();
    return success;
  }

  // ----------------------------------------------------------------------
  // --- منطق جلب بيانات البائع (للحصول على المناطق المحفوظة) ---
  // ----------------------------------------------------------------------
  
  Map<String, dynamic>? _sellerData;
  Map<String, dynamic>? get sellerData => _sellerData;

  // 🛠️ دالة جلب بيانات البائع
  Future<void> fetchSellerData() async {
    if (_auth.currentUser == null) return;

    try {
      final userDoc = await _db.collection("sellers").doc(_auth.currentUser!.uid).get();
      if (userDoc.exists) {
        _sellerData = userDoc.data();
      } else {
        _sellerData = null;
      }
    } catch (e) {
      debugPrint('Error fetching seller data: $e');
      _sellerData = null;
    }
  }

  // ----------------------------------------------------------------------
  // --- منطق جلب البيانات من Firebase ---
  // ----------------------------------------------------------------------

  Future<void> loadDashboardData(String sellerId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ordersQuery = _db
          .collection("orders")
          .where("sellerId", isEqualTo: sellerId);

      final ordersSnapshot = await ordersQuery.get();

      int totalOrders = 0;
      double completedSales = 0.0;
      int pendingOrders = 0;
      int newOrders = 0;

      for (var doc in ordersSnapshot.docs) {
        final orderData = doc.data();
        totalOrders++;

        final status = orderData['status']?.toString().toLowerCase().trim() ?? '';

        final isDelivered = (status == 'تم التوصيل' || status == 'delivered');
        if (isDelivered) {
          completedSales += (orderData['total'] is num) ? (orderData['total'] as num).toDouble() : 0.0;
        }

        const cancelledStatuses = {'ملغى', 'cancelled', 'rejected', 'failed'};
        final isCancelled = cancelledStatuses.contains(status);

        if (!isDelivered && !isCancelled) {
          pendingOrders++;
        }

        if (status == 'new-order') {
          newOrders++;
        }
      }

      await fetchDeliveryAreas();
      await fetchSellerData();

      // 🟢🟢 حل خطأ sellerName: تمرير _sellerName المحفوظ في الكنترولر 🟢🟢
      _data = SellerDashboardData(
        totalOrders: totalOrders,
        completedSalesAmount: completedSales,
        pendingOrdersCount: pendingOrders,
        newOrdersCount: newOrders,
        sellerName: _sellerName ?? 'البائع', // ⭐️ تم تصحيح هذا السطر
      );
    } on FirebaseException catch (e) {
      _errorMessage = 'خطأ في جلب بيانات لوحة التحكم: ${e.code}';
      debugPrint('Firebase Error: $e');
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع.';
      debugPrint('General Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- منطق المصادقة والترحيب ---

  Future<void> initializeAuthState(BuildContext context) async {
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        try {
          final userDoc = await _db.collection("sellers").doc(user.uid).get();
          if (!context.mounted) return;

          if (userDoc.exists) {
            final userData = userDoc.data();
            if (userData?['role'] == 'seller' && userData?['status'] == 'active') {
              // ⭐️ تعيين الاسم هنا ليتم استخدامه في loadDashboardData
              _sellerName = userData?['fullname'] as String?; 
              await loadDashboardData(user.uid); // تحميل البيانات ومناطق التوصيل
            } else {
              _signOutAndRedirect(context, "ليس لديك صلاحية للدخول أو حسابك غير مفعل.");
            }
          } else {
            _signOutAndRedirect(context, "بيانات المستخدم غير موجودة.");
          }
        } catch (e) {
          _signOutAndRedirect(context, "خطأ في التحقق من البيانات.");
        }
      } else {
        // لا يوجد مستخدم مسجل الدخول
      }
    });
  }

  void _signOutAndRedirect(BuildContext context, String message) async {
    if (!context.mounted) return;

    await _auth.signOut();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
  }

  Future<void> logout(BuildContext context) async {
    try {
      await _auth.signOut();
      _signOutAndRedirect(context, "تم تسجيل الخروج بنجاح.");
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تسجيل الخروج. يرجى المحاولة مرة أخرى.')),
      );
      debugPrint("Error signing out: $e");
    }
  }
}
