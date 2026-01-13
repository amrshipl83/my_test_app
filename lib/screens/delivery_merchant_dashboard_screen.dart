// lib/screens/delivery_merchant_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/widgets/delivery_merchant_sidebar_widget.dart';

// 1. موديل البيانات (يظل كما هو)
class DashboardData {
  final int totalProducts;
  final int totalOrders;
  final int pendingOrders;
  final double totalSales;

  DashboardData({
    required this.totalProducts,
    required this.totalOrders,
    required this.pendingOrders,
    required this.totalSales,
  });
}

class DeliveryMerchantDashboardScreen extends StatefulWidget {
  static const routeName = '/deliveryMerchantDashboard'; 

  const DeliveryMerchantDashboardScreen({super.key});

  @override
  State<DeliveryMerchantDashboardScreen> createState() => _DeliveryMerchantDashboardScreenState();
}

class _DeliveryMerchantDashboardScreenState extends State<DeliveryMerchantDashboardScreen> {
  Future<DashboardData>? _dashboardDataFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 3. دالة جلب البيانات (يظل المنطق كما هو تماماً)
  Future<DashboardData> _fetchDashboardData(String userId) async {
    final productsRef = _firestore.collection("marketOffer");
    final activeOffersQuery = productsRef
        .where("ownerId", isEqualTo: userId)
        .where("status", isEqualTo: "active");

    final productsSnapshot = await activeOffersQuery.count().get();
    final totalProducts = productsSnapshot.count;

    final ordersRef = _firestore.collection("consumerorders");
    
    final allOrdersQuery = ordersRef.where("supermarketId", isEqualTo: userId);
    final allOrdersSnapshot = await allOrdersQuery.count().get();
    final totalOrders = allOrdersSnapshot.count;
    
    final pendingOrdersQuery = ordersRef
        .where("supermarketId", isEqualTo: userId)
        .where("status", whereIn: ["new-order", "pending"]);

    final pendingOrdersSnapshot = await pendingOrdersQuery.count().get();
    final pendingOrders = pendingOrdersSnapshot.count;
    
    final deliveredOrdersQuery = ordersRef
        .where("supermarketId", isEqualTo: userId)
        .where("status", isEqualTo: "delivered");

    final deliveredOrdersDocs = await deliveredOrdersQuery.get();
    double totalSales = 0;
    for (var doc in deliveredOrdersDocs.docs) {
      final data = doc.data();
      if (data.containsKey('finalAmount') && data['finalAmount'] != null) {
        totalSales += double.tryParse(data['finalAmount'].toString()) ?? 0.0;
      }
    }

    return DashboardData(
      totalProducts: totalProducts ?? 0,
      totalOrders: totalOrders ?? 0,
      pendingOrders: pendingOrders ?? 0,
      totalSales: totalSales,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dashboardDataFuture == null) {
      final buyerData = Provider.of<BuyerDataProvider>(context, listen: false);
      final userId = buyerData.loggedInUser?.id;
      
      if (userId != null && userId.isNotEmpty) {
        _dashboardDataFuture = _fetchDashboardData(userId);
      } else {
        _dashboardDataFuture = Future.error("لم يتم تسجيل الدخول");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<BuyerDataProvider>(context).loggedInUser?.fullname ?? 'التاجر';
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.grey[50], // خلفية فاتحة ومريحة
      appBar: AppBar(
        title: const Text('لوحة تحكم المتجر', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      drawer: const DeliveryMerchantSidebarWidget(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.withOpacity(0.05)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // قسم الترحيب المطور
              _buildWelcomeHeader(userName, primaryColor),

              const SizedBox(height: 32),
              
              FutureBuilder<DashboardData>(
                future: _dashboardDataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(50.0),
                      child: CircularProgressIndicator(),
                    ));
                  } else if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  } else if (snapshot.hasData) {
                    final data = snapshot.data!;
                    return _buildStatsGrid(data, context);
                  }
                  return const Center(child: Text('لا توجد بيانات متاحة حالياً.'));
                },
              ),

              const SizedBox(height: 40),
              
              // بطاقة إرشادية سريعة
              _buildInfoFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(String name, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'أهلاً بك، $name 👋',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 4),
        Text(
          'إليك ملخص أداء متجرك اليوم',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  Widget _buildStatsGrid(DashboardData data, BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _DashboardCard(
          icon: Icons.inventory_2_outlined,
          title: 'المنتجات',
          value: data.totalProducts.toString(),
          color: Colors.blue,
        ),
        _DashboardCard(
          icon: Icons.shopping_bag_outlined,
          title: 'الطلبات',
          value: data.totalOrders.toString(),
          color: Colors.orange,
        ),
        _DashboardCard(
          icon: Icons.hourglass_empty_rounded,
          title: 'انتظار',
          value: data.pendingOrders.toString(),
          color: Colors.redAccent,
        ),
        _DashboardCard(
          icon: Icons.monetization_on_outlined,
          title: 'المبيعات',
          value: '${data.totalSales.toStringAsFixed(0)} ج.م',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
      child: Text('خطأ: $error', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
    );
  }

  Widget _buildInfoFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'يمكنك إدارة المنتجات والطلبات بشكل كامل من خلال القائمة الجانبية.',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ويدجت البطاقة الفرعية بتصميم عصري
class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _DashboardCard({
    required this.icon, 
    required this.title, 
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
