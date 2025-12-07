import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // لتنسيق التاريخ والعملة
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';

// ⚠️ ملاحظة: هذا الكود يفترض أن لديك حزمة cloud_firestore و font_awesome_flutter و intl مثبتة.

// ====================================================================
// A. النماذج (Models)
// ====================================================================

class OrderItemModel {
  final String name;
  final int quantity;
  final double price; // سعر البائع/المشتري
  final double pricePerUnit; // سعر المستهلك
  final String? imageUrl;

  OrderItemModel({
    required this.name,
    required this.quantity,
    required this.price,
    required this.pricePerUnit,
    this.imageUrl,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json, {required bool isConsumer}) {
    // استخدم keys من كود HTML/JS: name, quantity, price/pricePerUnit, imageUrl
    return OrderItemModel(
      name: json['name'] as String? ?? 'منتج غير معروف',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      pricePerUnit: (json['pricePerUnit'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class MyOrderModel {
  final String id;
  final String status;
  final DateTime orderDate;
  final double total;
  final List<OrderItemModel> items;

  MyOrderModel({
    required this.id,
    required this.status,
    required this.orderDate,
    required this.total,
    required this.items,
  });

  String get statusText {
    switch (status) {
      case 'new-order': return 'طلب جديد';
      case 'processing': return 'قيد المعالجة';
      case 'shipped': return 'تم الشحن';
      case 'delivered': return 'تم التوصيل';
      case 'cancelled': return 'ملغي';
      case 'completed': return 'مكتمل';
      default: return status;
    }
  }

  String get orderDateFormatted {
    // تنسيق التاريخ المطلوب (مثل: 13 مايو، 2023 05:30 م)
    return DateFormat('d MMMM, yyyy hh:mm a', 'ar').format(orderDate);
  }
}

// ====================================================================
// B. الريبوزيتوري (Repository) - جلب البيانات من Firestore
// ====================================================================

class MyOrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // تعريفات افتراضية لدور المستخدم (يجب تمريرها أو جلبها من Provider في التطبيق الحقيقي)
  String _currentUserId = 'TEST_USER_ID_123';
  String _currentUserRole = 'buyer';

  // يجب استخدام Constructor بدون const
  MyOrderRepository();

  // دالة لجلب الطلبات بناءً على منطق الـ HTML/JS
  Future<List<MyOrderModel>> fetchUserOrders() async {
    String collectionName;
    String queryField;
    String totalField;
    bool isConsumer = _currentUserRole == 'consumer';

    // تحديد المجموعة وحقول البيانات بناءً على الدور (طبقاً لمنطق الـ HTML/JS)
    if (_currentUserRole == 'buyer') {
      collectionName = "orders";
      queryField = "buyer.id";
      totalField = "total";
    } else if (_currentUserRole == 'consumer') {
      collectionName = "consumerorders";
      queryField = "customerId";
      totalField = "finalAmount";
    } else {
      // إذا كان الدور غير معروف، لا توجد طلبات
      return [];
    }

    // ⚠️ فحص وجود الـ ID
    if (_currentUserId.isEmpty) {
      // مؤقتاً:
      _currentUserId = 'TEST_USER_ID_123';
    }

    final ordersRef = _firestore.collection(collectionName);

    // الاستعلام: WHERE userField == userId ORDER BY orderDate DESC
    final q = ordersRef
        .where(queryField, isEqualTo: _currentUserId)
        .orderBy("orderDate", descending: true);

    final querySnapshot = await q.get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();

      // تحويل التاريخ من Timestamp
      final orderDate = (data['orderDate'] as Timestamp).toDate();

      // تحويل عناصر الطلب
      final items = (data['items'] as List<dynamic>)
          .map((itemJson) => OrderItemModel.fromJson(itemJson as Map<String, dynamic>, isConsumer: isConsumer))
          .toList();

      return MyOrderModel(
        id: doc.id,
        status: data['status'] as String? ?? 'غير محدد',
        orderDate: orderDate,
        total: (data[totalField] as num?)?.toDouble() ?? 0.0,
        items: items,
      );
    }).toList();
  }
}

// ====================================================================
// C. الشاشة الرئيسية (Screen) - MyOrdersScreen
// ====================================================================

// ✅ التصحيح: تحويلها إلى StatefulWidget لحل مشكلة تهيئة الـ Repository غير الثابت
class MyOrdersScreen extends StatefulWidget {
  static const String routeName = '/my_orders';

  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  // ✅ وضع الـ Repository هنا لتجنب أخطاء const
  final MyOrderRepository repository = MyOrderRepository(); 
  late Future<List<MyOrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    // بدء عملية جلب البيانات مرة واحدة عند التهيئة
    _ordersFuture = repository.fetchUserOrders();
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 الفهرس 0 هو "مشترياتي" وفقاً لطلبك 🟢
    const int activeIndex = 0;

    return Scaffold(
      // 1. الرأس العلوي (Top Header)
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(FontAwesomeIcons.receipt, size: 18),
            SizedBox(width: 10),
            Text('طلباتي'),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF74D19C), Color(0xFF4CAF50)], // top-header-bg
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        foregroundColor: Colors.white, // top-header-text
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.moon), // Theme Toggle
            onPressed: () {
              // TODO: إضافة منطق تبديل الوضع الليلي
            },
          ),
        ],
        // ✅ إضافة زر العودة إلى الشاشة الرئيسية
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            // نستخدم pushReplacementNamed للعودة إلى الشاشة الرئيسية
            Navigator.of(context).pushReplacementNamed(BuyerHomeScreen.routeName);
          },
        ),
      ),

      // 2. المحتوى الرئيسي (Main Content)
      body: FutureBuilder<List<MyOrderModel>>(
        future: _ordersFuture, // استخدام الـ Future الذي تم تعريفه في initState
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: _NoOrdersMessage(
              icon: FontAwesomeIcons.spinner,
              message: 'جاري تحميل طلباتك...',
              isSpinning: true,
            ));
          }

          if (snapshot.hasError) {
            return Center(child: _NoOrdersMessage(
              icon: FontAwesomeIcons.exclamationCircle,
              message: 'حدث خطأ: ${snapshot.error.toString()}',
              isError: true,
            ));
          }

          final orders = snapshot.data;

          if (orders == null || orders.isEmpty) {
            return const Center(child: _NoOrdersMessage(
              icon: FontAwesomeIcons.boxOpen,
              message: 'لا توجد طلبات سابقة لهذا الحساب.',
            ));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              return _OrderCard(order: orders[index]);
            },
          );
        },
      ),

      // 3. شريط التنقل السفلي (Bottom Navigation)
      bottomNavigationBar: _BottomNav(activeIndex: activeIndex),
    );
  }
}

// ====================================================================
// D. الـ Widgets المساعدة (لم يتم تعديلها بشكل جوهري)
// ====================================================================

// Widget لتمثيل البطاقة
class _OrderCard extends StatelessWidget {
  final MyOrderModel order;
  const _OrderCard({required this.order});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new-order': return const Color(0xFF3498DB);
      case 'processing': return const Color(0xFFF39C12);
      case 'shipped': return const Color(0xFF2ECC71);
      case 'delivered': return const Color(0xFF27AE60);
      case 'cancelled': return const Color(0xFFE74C3C);
      case 'completed': return const Color(0xFF1ABC9C);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);
    // الاعتماد على الـ Directionality الخارجي وعدم استخدام متغيرات الريبوزيتوري الخاصة مباشرة
    const isConsumer = true;
    final orderTotalText = 'الإجمالي: ${order.total.toStringAsFixed(2)} جنيه';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border(
          right: BorderSide(color: statusColor, width: 5), // شريط جانبي
        ),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (ID and Status)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // إزالة 'textDirection: TextDirection.ltr' هنا
              Text(
                'رقم الطلب: ${order.id}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  order.statusText,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 15, thickness: 0.5, color: Color(0xFFDDDDDD)),

          // Date
          // إزالة 'textDirection: TextDirection.rtl' هنا
          Text(
            'تاريخ الطلب: ${order.orderDateFormatted}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF777777)),
          ),
          const SizedBox(height: 10),

          // Items List
          ...order.items.map((item) {
            final unitPrice = isConsumer ? item.pricePerUnit : item.price;
            final qtyPriceText = 'الكمية: ${item.quantity} × ${unitPrice.toStringAsFixed(2)} ج';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFDDDDDD)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.network(
                        item.imageUrl ?? 'https://via.placeholder.com/40?text=صورة',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 20, color: Color(0xFFDDDDDD)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(qtyPriceText, style: const TextStyle(fontSize: 12, color: Color(0xFF777777))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          const Divider(height: 15, thickness: 1, color: Color(0xFFDDDDDD)),

          // Total
          Align(
            alignment: Alignment.centerRight, // محاذاة لليمين للنص العربي
            // إزالة 'textDirection: TextDirection.rtl' هنا
            child: Text(
              orderTotalText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF388E3C), // primary-dark-color
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget لرسائل حالة التحميل/الخطأ/عدم وجود بيانات
class _NoOrdersMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isSpinning;
  final bool isError;

  const _NoOrdersMessage({
    required this.icon,
    required this.message,
    this.isSpinning = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            icon,
            size: 50,
            color: isError ? Colors.red : const Color(0xFFDDDDDD),
          ),
          const SizedBox(height: 15),
          isSpinning
              ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)))
              : const SizedBox.shrink(),
          if (isSpinning) const SizedBox(height: 15),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Color(0xFF777777)),
          ),
        ],
      ),
    );
  }
}

// Widget لشريط التنقل السفلي (Bottom Navigation)
class _BottomNav extends StatelessWidget {
  final int activeIndex;

  const _BottomNav({required this.activeIndex});

  // تحديد عناصر شريط التنقل للمشتري/المستهلك (بافتراض نفس العناصر للمثال)
  List<Map<String, dynamic>> getNavItems() {
    return [
      { 'route': MyOrdersScreen.routeName, 'icon': FontAwesomeIcons.receipt, 'label': 'مشترياتي', 'isCart': false },
      { 'route': '/store', 'icon': FontAwesomeIcons.home, 'label': 'المتجر', 'isCart': false },
      { 'route': '/search', 'icon': FontAwesomeIcons.search, 'label': 'البحث', 'isCart': false },
      { 'route': '/cart', 'icon': FontAwesomeIcons.shoppingCart, 'label': 'السلة', 'isCart': true },
      { 'route': BuyerHomeScreen.routeName, 'icon': FontAwesomeIcons.user, 'label': 'حسابي', 'isCart': false },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final navItems = getNavItems();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: BottomNavigationBar(
        items: navItems.map((item) {
          return BottomNavigationBarItem(
            icon: Stack(
              children: [
                Icon(item['icon'] as IconData),
                // TODO: إضافة Badge للسلة هنا إذا كانت 'isCart' صحيحة
              ],
            ),
            label: item['label'] as String,
          );
        }).toList(),
        currentIndex: activeIndex,
        onTap: (index) {
          if (index != activeIndex) {
            // منطق التوجيه: يستخدم pushReplacementNamed للتنقل
            Navigator.of(context).pushReplacementNamed(navItems[index]['route'] as String);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: const Color(0xFF888888),
        backgroundColor: Colors.transparent, // مهم لكي يظهر لون الحاوية
        elevation: 0, // مهم لكي لا يكون هناك ظل إضافي
      ),
    );
  }
}
