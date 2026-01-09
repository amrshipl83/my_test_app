import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';

// استيراد الشاشات والمحتويات
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';
import 'package:my_test_app/screens/buyer/cart_screen.dart';
import 'package:my_test_app/screens/buyer/traders_screen.dart'; // سنأخذ منها TradersContent
import 'package:my_test_app/widgets/home_content.dart'; // محتوى الصفحة الرئيسية

// استيراد الودجت المساعدة
import 'package:my_test_app/widgets/buyer_header_widget.dart';
import 'package:my_test_app/widgets/buyer_mobile_nav_widget.dart';
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
  int _selectedIndex = 1; // الافتراضي هو الرئيسية (HomeContent)

  String _userName = 'مرحباً بك!';
  String? _currentUserId;
  int _newOrdersCount = 0;
  int _cartCount = 0;
  bool _deliverySettingsAvailable = false;
  bool _deliveryPricesAvailable = false;
  bool _deliveryIsActive = false;

  // 🎯 تعريف قائمة الصفحات كمحتوى (Body) فقط لمنع التداخل
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // إعداد الصفحات التي ستظهر في الـ Bottom Navigation
    _pages = [
      // التبويب 0: التجار (نرسل showHeader: false لإخفاء الهيدر المكرر)
      const TradersContent(showHeader: false), 
      // التبويب 1: الرئيسية
      const HomeContent(), 
      // التبويب 2: طلباتي (تأكد أن صفحة MyOrdersScreen لا تحتوي على Scaffold داخلي)
      const MyOrdersScreen(),
      // التبويب 3: السلة
      const CartScreen(),
    ];
    _initializeAppLogic();
  }

  // --- منطق الإشعارات (كما في الأصل تماماً) ---
  Future<void> _setupNotifications() async {
    if (_currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    bool alreadyShown = prefs.getBool('notifications_dialog_shown') ?? false;
    if (alreadyShown) return;

    if (!mounted) return;
    bool? userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("تفعيل التنبيهات", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: const Text("يرجى تفعيل التنبيهات لتتمكن من متابعة حالة طلباتك والعروض الجديدة فور حدوثها.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ليس الآن", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text("موافق", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    await prefs.setBool('notifications_dialog_shown', true);
    if (userAgreed == true) {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          await _db.collection('users').doc(_currentUserId).update({
            'fcmToken': token,
            'role': 'buyer',
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'notificationsEnabled': true,
          });
        }
      }
    }
  }

  // --- منطق تحميل البيانات (كما في الأصل) ---
  void _initializeAppLogic() async {
    final userAuth = _auth.currentUser;
    if (userAuth == null) return;
    _currentUserId = userAuth.uid;
    _setupNotifications();

    final prefs = await SharedPreferences.getInstance();
    _updateCartCount(prefs);

    try {
      final userDoc = await _db.collection('users').doc(_currentUserId).get();
      if (userDoc.exists && mounted) {
        final fullName = userDoc.data()?['fullname'] ?? 'زائر أكسب';
        setState(() => _userName = 'أهلاً بك، $fullName!');
      }
    } catch (e) { debugPrint('Error: $e'); }
    
    await _checkDeliveryStatusAndDisplayIcons();
    await _updateNewDealerOrdersCount();
  }

  void _updateCartCount(SharedPreferences prefs) {
    String? cartData = prefs.getString('cart_items');
    if (cartData != null) {
      List<dynamic> items = jsonDecode(cartData);
      if (mounted) setState(() => _cartCount = items.length);
    }
  }

  Future<void> _checkDeliveryStatusAndDisplayIcons() async {
    if (_currentUserId == null) return;
    try {
      final approvedSnapshot = await _db.collection('deliverySupermarkets')
          .where("ownerId", isEqualTo: _currentUserId).get();
      if (approvedSnapshot.docs.isNotEmpty) {
        final docData = approvedSnapshot.docs.first.data();
        if (mounted) setState(() { _deliveryIsActive = docData['isActive'] ?? false; _deliveryPricesAvailable = true; });
      } else {
        if (mounted) setState(() => _deliverySettingsAvailable = true);
      }
    } catch (e) { debugPrint("Delivery Error: $e"); }
  }

  Future<void> _updateNewDealerOrdersCount() async {
    if (_currentUserId == null) return;
    final q = await _db.collection('consumerorders')
        .where("supermarketId", isEqualTo: _currentUserId)
        .where("status", isEqualTo: "new-order").get();
    if (mounted) setState(() => _newOrdersCount = q.size);
  }

  // 🎯 عند التنقل بين التبويبات
  void _onItemTapped(int index) {
    if (mounted) {
      setState(() => _selectedIndex = index);
      // تحديث السلة لحظياً عند التنقل
      SharedPreferences.getInstance().then((prefs) => _updateCartCount(prefs));
    }
  }

  void _handleLogout() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) { debugPrint('Logout Error: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFf5f7fa),
        // 1. القائمة الجانبية (Drawer)
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
            // 2. الهيدر العلوي (يحتوي على "أهلاً بك" والمنيو)
            BuyerHeaderWidget(
              onMenuToggle: () => _scaffoldKey.currentState?.openEndDrawer(),
              menuNotificationDotActive: _newOrdersCount > 0,
              userName: _userName,
              onLogout: _handleLogout,
            ),
            // 3. المحتوى المتغير (IndexedStack)
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages, // تم استخدام المحتويات فقط هنا
              ),
            ),
          ],
        ),
        // 4. البار السفلي الموحد
        bottomNavigationBar: BuyerMobileNavWidget(
          selectedIndex: _selectedIndex,
          onItemSelected: _onItemTapped,
          cartCount: _cartCount,
          ordersChanged: false,
        ),
        // 5. المساعد الذكي (يظهر مرة واحدة فقط لكل التبويبات)
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
