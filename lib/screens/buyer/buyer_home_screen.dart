// المسار: lib/screens/buyer/buyer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';

// الاستيرادات الأساسية
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';
import 'package:my_test_app/screens/buyer/cart_screen.dart';
import 'package:my_test_app/screens/buyer/traders_screen.dart';
import 'package:my_test_app/widgets/buyer_header_widget.dart';
import 'package:my_test_app/widgets/buyer_mobile_nav_widget.dart';
// 🎯 استيراد ودجت الشات
import 'package:my_test_app/widgets/chat_support_widget.dart'; 

final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _db = FirebaseFirestore.instance;

class BuyerHomeScreen extends StatefulWidget {
  static const String routeName = '/buyerHome';
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 1; // الشاشة الرئيسية (المتجر) افتراضياً

  String _userName = 'مرحباً بك!';
  String? _currentUserId;
  int _newOrdersCount = 0;
  int _cartCount = 0;
  bool _ordersChanged = false;
  bool _deliverySettingsAvailable = false;
  bool _deliveryPricesAvailable = false;
  bool _deliveryIsActive = false;

  @override
  void initState() {
    super.initState();
    _initializeAppLogic();
  }

  // 🎯 دالة طلب إذن الإشعارات وحفظ التوكن للمشتري
  Future<void> _setupNotifications() async {
    if (_currentUserId == null) return;

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();
      if (token != null) {
        await _db.collection('users').doc(_currentUserId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _handleLogout() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userRole');
      await prefs.remove('loggedUser');
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      print('حدث خطأ أثناء تسجيل الخروج: $e');
    }
  }

  void _initializeAppLogic() async {
    final userAuth = _auth.currentUser;
    if (userAuth == null) return;
    _currentUserId = userAuth.uid;

    await _setupNotifications();
    final prefs = await SharedPreferences.getInstance();
    _updateCartCount(prefs);

    try {
      final userDoc = await _db.collection('users').doc(_currentUserId).get();
      if (userDoc.exists) {
        final fullName = userDoc.data()?['fullname'] ?? 'زائر أكسب';
        if (mounted) {
          setState(() => _userName = 'أهلاً بك، $fullName!');
        }
      }
    } catch (e) {
      print('Error: $e');
    }
    await _checkDeliveryStatusAndDisplayIcons();
    await _updateNewDealerOrdersCount();
    await _monitorUserOrdersStatusChanges();
  }

  void _updateCartCount(SharedPreferences prefs) {
    if (mounted) setState(() => _cartCount = 5); // قيمة تجريبية
  }

  Future<void> _checkDeliveryStatusAndDisplayIcons() async {
    final dealerId = _currentUserId;
    if (dealerId == null) return;
    try {
      final approvedSnapshot = await _db
          .collection('deliverySupermarkets')
          .where("ownerId", isEqualTo: dealerId)
          .get();

      if (approvedSnapshot.docs.isNotEmpty) {
        final docData = approvedSnapshot.docs.first.data();
        if (docData['isActive'] == true) {
          if (mounted) {
            setState(() {
              _deliveryPricesAvailable = true;
              _deliveryIsActive = true;
            });
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _deliverySettingsAvailable = true;
          _deliveryIsActive = false;
        });
      }
    } catch (e) {
      print("Delivery Status Error: $e");
    }
  }

  Future<void> _updateNewDealerOrdersCount() async {
    if (_currentUserId == null) return;
    final q = await _db
        .collection('consumerorders')
        .where("supermarketId", isEqualTo: _currentUserId)
        .where("status", isEqualTo: "new-order")
        .get();
    if (mounted) setState(() => _newOrdersCount = q.size);
  }

  Future<void> _monitorUserOrdersStatusChanges() async {
    if (_currentUserId == null) return;
    if (mounted) setState(() => _ordersChanged = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFf5f7fa),
        endDrawer: BuyerHeaderWidget.buildSidebar(
          context: context,
          onLogout: _handleLogout,
          newOrdersCount: _newOrdersCount,
          deliverySettingsAvailable: _deliverySettingsAvailable,
          deliveryPricesAvailable: _deliveryPricesAvailable,
          deliveryIsActive: _deliveryIsActive,
        ),
        body: Column(
          children: <Widget>[
            BuyerHeaderWidget(
              onMenuToggle: () => _scaffoldKey.currentState?.openEndDrawer(),
              menuNotificationDotActive: _newOrdersCount > 0,
              userName: _userName,
              onLogout: _handleLogout,
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: BuyerMobileNavWidget.mainPages,
              ),
            ),
          ],
        ),
        bottomNavigationBar: BuyerMobileNavWidget(
          selectedIndex: _selectedIndex,
          onItemSelected: _onItemTapped,
          cartCount: _cartCount,
          ordersChanged: _ordersChanged,
        ),
        // 🚀 تم تحديث زر الشات هنا ليعمل مع المساعد الذكي
        floatingActionButton: FloatingActionButton(
          heroTag: "buyer_home_chat_btn",
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const ChatSupportWidget(),
            );
          },
          backgroundColor: const Color(0xFF4CAF50),
          child: const Icon(Icons.support_agent, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

