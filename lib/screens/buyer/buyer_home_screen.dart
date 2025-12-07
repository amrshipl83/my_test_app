// المسار: lib/screens/buyer/buyer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; 

// 🟢 [الاستيراد الأساسي]
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';
import 'package:my_test_app/screens/buyer/cart_screen.dart';       
import 'package:my_test_app/screens/buyer/traders_screen.dart';    
import 'package:my_test_app/screens/search/search_screen.dart'; 

// استيراد الأجزاء المقسمة
import '../../widgets/buyer_header_widget.dart';
import '../../widgets/buyer_mobile_nav_widget.dart';

// تعريفات Firebase 
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
  
  // 💡 Index 1 هو الأيقونة التي تمثل الشاشة الرئيسية في الشريط السفلي (افتراضياً)
  int _selectedIndex = 1; 

  // --- 💡 المتغيرات الحقيقية ---
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

  void _onItemTapped(int index) {
    // ⭐️ الخطوة 1: تحديث الـ Index لتغيير لون/حالة الأيقونة في الشريط السفلي (ضروري للشكل)
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }

    // 🟢 تعريف فهارس الأيقونات الخمسة والمسارات الخاصة بها
    const int myOrdersIndex = 0;
    const int homeScreenIndex = 1;      // أيقونة المتجر/الرئيسية
    const int cartIndex = 2;
    const int tradersIndex = 3;
    const int walletIndex = 4;
    
    // ⚠️ إذا ضغط المستخدم على أيقونة الشاشة الرئيسية (Index 1)، لا يحدث أي توجيه خارجي
    if (index == homeScreenIndex) {
      return; 
    }

    // 1. مشترياتي (Index 0): توجيه خارجي
    if (index == myOrdersIndex) {
      Navigator.of(context).pushNamed(MyOrdersScreen.routeName);
      return;
    }
    
    // 2. البحث (Index 1): تم التعامل معها أعلاه (لا توجيه خارجي)

    // 3. السلة (Index 2): توجيه خارجي
    if (index == cartIndex) {
      Navigator.of(context).pushNamed(CartScreen.routeName);
      return;
    }
    
    // 4. التجار (Index 3): توجيه خارجي
    if (index == tradersIndex) {
      Navigator.of(context).pushNamed(TradersScreen.routeName);
      return;
    }
    
    // 5. محفظتي (Index 4): توجيه خارجي
    if (index == walletIndex) {
      Navigator.of(context).pushNamed('/wallet');
      return;
    }
  }

  // 💡 دالة تسجيل الخروج المنقولة بالكامل هنا لتكون نقطة تحكم واحدة
  void _handleLogout() async {
    try {
      await _auth.signOut();
      // محاكاة لمسح البيانات من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_token');
      await prefs.remove('loggedUser');
      await prefs.remove('userOrdersSnapshot');
      if (mounted) {
        // توجيه لصفحة تسجيل الخروج (افتراضياً '/')
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      print('حدث خطأ أثناء تسجيل الخروج: $e');
    }
  }

  // --- 🎯 منطق جلب البيانات من Local Storage و Firestore (تم الحفاظ عليه كاملاً) ---
  void _initializeAppLogic() async {
    final userAuth = _auth.currentUser;
    if (userAuth == null) { return; }

    _currentUserId = userAuth.uid;
    final prefs = await SharedPreferences.getInstance();
    _updateCartCount(prefs);

    try {
      final userDoc = await _db.collection('users').doc(_currentUserId).get();
      if (userDoc.exists) {
        final fullName = userDoc.data()?['fullname'] ?? 'زائر أكسب';
        if (mounted) {
          setState(() {
            _userName = 'أهلاً بك، $fullName!';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userName = 'أهلاً بك، زائر أكسب!';
          });
        }
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }

    await _checkDeliveryStatusAndDisplayIcons();
    await _updateNewDealerOrdersCount();
    await _monitorUserOrdersStatusChanges();
  }

  void _updateCartCount(SharedPreferences prefs) {
    if(mounted) {
      setState(() {
        _cartCount = 5; 
      });
    }
  }

  void _updateMyOrdersSnapshot(String userId) async {
    try {
      final ordersRef = _db.collection('consumerorders');
      final q = ordersRef
          .where("userId", isEqualTo: userId)
          .orderBy("orderDate", descending: true)
          .get();

      final querySnapshot = await q;
      List<Map<String, dynamic>> ordersToStore = [];
      querySnapshot.docs.forEach((doc) {
        ordersToStore.add({ 'id': doc.id, 'status': doc.data()['status'] });
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userOrdersSnapshot', jsonEncode(ordersToStore));

      if (mounted) {
        setState(() {
          _ordersChanged = false;
        });
      }
    } catch (error) {
      print("خطأ أثناء تحديث snapshot طلبات المستخدم: $error");
    }
  }

  Future<void> _checkDeliveryStatusAndDisplayIcons() async {
    final dealerId = _currentUserId;
    if (dealerId == null) { return; }

    try {
      final approvedQ = _db.collection('deliverySupermarkets')
          .where("ownerId", isEqualTo: dealerId)
          .get();

      final approvedSnapshot = await approvedQ;
      if (approvedSnapshot.docs.isNotEmpty) {
        final docData = approvedSnapshot.docs.first.data();
        if (docData['isActive'] == true) {
          if(mounted) {
            setState(() {
              _deliveryPricesAvailable = true;
              _deliveryIsActive = true;
            });
          }
          return;
        } else {
          return;
        }
      }

      final pendingQ = _db.collection('pendingSupermarkets')
          .where("ownerId", isEqualTo: dealerId)
          .get();

      final pendingSnapshot = await pendingQ;
      if (pendingSnapshot.docs.isNotEmpty) { return; }

      if(mounted) {
        setState(() {
          _deliverySettingsAvailable = true;
          _deliveryIsActive = false;
        });
      }

    } catch (error) {
      print("خطأ حرج أثناء التحقق من حالة الدليفري: $error");
    }
  }

  Future<void> _updateNewDealerOrdersCount() async {
    final dealerId = _currentUserId;
    if (dealerId == null) { return; }

    try {
      final ordersRef = _db.collection('consumerorders');
      final q = ordersRef
          .where("supermarketId", isEqualTo: dealerId)
          .where("status", isEqualTo: "new-order")
          .get();

      final querySnapshot = await q;
      final count = querySnapshot.size;

      if (mounted) {
        setState(() {
          _newOrdersCount = count;
        });
      }
    } catch (error) {
      print("خطأ أثناء جلب عدد طلبات الدليفري الجديدة للتاجر: $error");
    }
  }

  Future<void> _monitorUserOrdersStatusChanges() async {
    final userId = _currentUserId;
    if (userId == null) { return; }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedOrdersString = prefs.getString('userOrdersSnapshot');

      final List<dynamic> storedOrders = storedOrdersString != null
          ? jsonDecode(storedOrdersString) as List<dynamic>
          : [];

      final userOrdersRef = _db.collection('consumerorders');
      final q = userOrdersRef
          .where("userId", isEqualTo: userId)
          .orderBy("orderDate", descending: true)
          .get();

      final querySnapshot = await q;
      List<Map<String, dynamic>> currentOrders = [];
      querySnapshot.docs.forEach((doc) {
        currentOrders.add({ 'id': doc.id, 'status': doc.data()['status'] });
      });

      bool hasChanges = false;

      if (currentOrders.length != storedOrders.length) {
        hasChanges = true;
      } else {
        final storedOrdersMap = Map<String, dynamic>.fromIterable(
          storedOrders,
          key: (order) => order['id'],
          value: (order) => order['status'],
        );

        for (final currentOrder in currentOrders) {
          if (storedOrdersMap[currentOrder['id']] != currentOrder['status']) {
            hasChanges = true;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _ordersChanged = hasChanges;
        });
      }

    } catch (error) {
      print("خطأ أثناء مراقبة تغييرات حالات طلبات المستخدم: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFf5f7fa),

        // القائمة الجانبية (Sidebar)
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
            // الرأس العلوي (Top Header)
            BuyerHeaderWidget(
              onMenuToggle: () => _scaffoldKey.currentState?.openEndDrawer(),
              menuNotificationDotActive: _newOrdersCount > 0, 
              userName: _userName, 
              onLogout: _handleLogout,
            ),

            // ⭐️ التعديل الحاسم: المحتوى الأساسي (البانرات) يظهر دائماً في Index 1.
            Expanded(
              child: BuyerMobileNavWidget.mainPages.elementAt(1), // ✅ ثابت على Index 1 (المحتوى الأساسي)
            ),
          ],
        ),

        // شريط التنقل السفلي
        bottomNavigationBar: BuyerMobileNavWidget(
          selectedIndex: _selectedIndex,
          onItemSelected: _onItemTapped,
          cartCount: _cartCount, 
          ordersChanged: _ordersChanged, 
        ),

        // زر المحادثة العائم
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('زر محادثة الذكاء الاصطناعي معطل مؤقتاً.')),
            );
          },
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: const Icon(Icons.message_rounded),
        ),
      ),
    );
  }
}
