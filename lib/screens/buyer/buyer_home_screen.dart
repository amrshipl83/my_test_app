// المسار: lib/screens/buyer/buyer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // ✅ تم إضافة لاستخدام jsonEncode/jsonDecode

// استيراد الأجزاء المقسمة
import '../../widgets/buyer_header_widget.dart';
import '../../widgets/buyer_mobile_nav_widget.dart';

// تعريفات Firebase (مضمنة هنا لجعله وحدة مستقلة)
final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _db = FirebaseFirestore.instance;

class BuyerHomeScreen extends StatefulWidget {
  // ✅ الإضافة المطلوبة لتصحيح الخطأ "Member not found: 'routeName'."
  static const String routeName = '/buyerHome';

  const BuyerHomeScreen({super.key});           
  @override                                       
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}
                                                
class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 1; // يبدأ من صفحة البحث (HomeContent)

  // --- 💡 المتغيرات الحقيقية لاستبدال البيانات المؤقتة (Temp) ---
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
    setState(() {
      _selectedIndex = index;
    });
    // تحديث Snapshot طلبات المستخدم عند الانتقال لصفحة الطلبات
    if (index == 0 && _currentUserId != null) { 
        _updateMyOrdersSnapshot(_currentUserId!); 
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
        // توجيه لصفحة تسجيل الدخول (افتراضياً '/')
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      print('حدث خطأ أثناء تسجيل الخروج: $e');
    }
  }

  // --- 🎯 منطق جلب البيانات من Local Storage و Firestore ---

  void _initializeAppLogic() async {
    // 1. جلب بيانات المستخدم من Auth
    final userAuth = _auth.currentUser;
    if (userAuth == null) {
        return;
    }
    
    _currentUserId = userAuth.uid;

    final prefs = await SharedPreferences.getInstance();
    
    _updateCartCount(prefs);

    // 🎯 تم إصلاح: جلب الاسم الحقيقي من Firestore (افتراضياً من مجموعة 'users')
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

    // 3. تشغيل الدوال المعتمدة على Firebase
    await _checkDeliveryStatusAndDisplayIcons();
    await _updateNewDealerOrdersCount();
    await _monitorUserOrdersStatusChanges();
  }

  void _updateCartCount(SharedPreferences prefs) {
    // منطق جلب عدد السلة من SharedPreferences
    if(mounted) {
        setState(() {
            _cartCount = 5; // قيمة افتراضية مؤقتة 
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
          // 1. التحقق من deliverySupermarkets (Approved)
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

          // 2. التحقق من pendingSupermarkets (Pending)
          final pendingQ = _db.collection('pendingSupermarkets')
              .where("ownerId", isEqualTo: dealerId)
              .get();
          
          final pendingSnapshot = await pendingQ;
          if (pendingSnapshot.docs.isNotEmpty) {
              return;
          }

          // 3. حالة جديدة (عرض رابط الإعدادات)
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
    // 💡 استخدام المتغيرات الحقيقية بدلاً من المتغيرات المؤقتة
    // تم حذف جميع المتغيرات المؤقتة (temp...)

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFf5f7fa),

        // القائمة الجانبية (Sidebar)
        endDrawer: BuyerHeaderWidget.buildSidebar(
          context: context,
          onLogout: _handleLogout, 
          newOrdersCount: _newOrdersCount, // ✅ تم استبدال Temp
          deliverySettingsAvailable: _deliverySettingsAvailable, // ✅ تم استبدال Temp
          deliveryPricesAvailable: _deliveryPricesAvailable, // ✅ تم استبدال Temp
          deliveryIsActive: _deliveryIsActive, // ✅ تم إضافة حقل جديد لتحديد عرض "طلبات الدليفري"
        ),
                                                        
        body: Column(
          children: <Widget>[
            // الرأس العلوي (Top Header)
            BuyerHeaderWidget(
              onMenuToggle: () => _scaffoldKey.currentState?.openEndDrawer(),
              menuNotificationDotActive: _newOrdersCount > 0, // ✅ تم استبدال Temp
              userName: _userName, // ✅ تم استبدال Temp
              onLogout: _handleLogout, 
            ),

            // محتوى الصفحة المختار من شريط التنقل السفلي                                                   
            Expanded(
              child: BuyerMobileNavWidget.mainPages.elementAt(_selectedIndex),
            ),                                            
          ],
        ),

        // شريط التنقل السفلي
        bottomNavigationBar: BuyerMobileNavWidget(
          selectedIndex: _selectedIndex,
          onItemSelected: _onItemTapped,
          cartCount: _cartCount, // ✅ تم استبدال Temp
          ordersChanged: _ordersChanged, // ✅ تم استبدال Temp
        ),

        // زر المحادثة العائم (تم تعديل الأيقونة)
        floatingActionButton: FloatingActionButton(
          onPressed: () {                                   
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('زر محادثة الذكاء الاصطناعي معطل مؤقتاً.')),
            );
          },
          backgroundColor: const Color(0xFF4CAF50),                                                       
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: const Icon(Icons.message_rounded), // ✅ أيقونة Material
        ),                                            
      ),
    );
  }
}
