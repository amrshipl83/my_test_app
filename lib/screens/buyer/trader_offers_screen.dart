import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/trader_offer_card.dart';

// ✅ 1. تفعيل استيراد صفحة التفاصيل واستخدام الـ Nav الموحد
import 'package:my_test_app/screens/product_details_screen.dart';
import 'package:my_test_app/widgets/buyer_mobile_nav_widget.dart';

class TraderOffersScreen extends StatefulWidget {
  static const String routeName = '/traderOffers';
  final String sellerId;
  
  const TraderOffersScreen({super.key, required this.sellerId});

  @override
  State<TraderOffersScreen> createState() => _TraderOffersScreenState();
}

class _TraderOffersScreenState extends State<TraderOffersScreen> {
  // 🎯 نحن في صفحة عروض التاجر، لذا نعتبر أنفسنا في قسم "التجار" (Index 0)
  final int _selectedIndex = 0;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCartCount();
  }

  // تحديث عداد السلة للشريط السفلي
  Future<void> _loadCartCount() async {
    final prefs = await SharedPreferences.getInstance();
    String? cartData = prefs.getString('cart_items');
    if (cartData != null) {
      List<dynamic> items = jsonDecode(cartData);
      if (mounted) setState(() => _cartCount = items.length);
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0: Navigator.pushReplacementNamed(context, '/traders'); break;
      case 1: Navigator.pushReplacementNamed(context, '/buyerHome'); break;
      case 2: Navigator.pushNamed(context, '/myOrders'); break;
      case 3: Navigator.pushReplacementNamed(context, '/wallet'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        toolbarHeight: 60,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isDarkMode ? const Color(0xff34495e) : const Color(0xff74d19c),
                isDarkMode ? const Color(0xff1e2a3b) : AppTheme.primaryGreen,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'عروض التاجر',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const Icon(Icons.local_offer_outlined, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
      body: OffersDataFetcher(sellerId: widget.sellerId), 
      // ✅ 2. توحيد الشريط السفلي مع نظام المسارات المعتمد
      bottomNavigationBar: BuyerMobileNavWidget(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemTapped,
        cartCount: _cartCount,
        ordersChanged: false,
      ),
    );
  }
}

// =========================================================================
// 🎯 OffersDataFetcher: معالجة ذكية لحقن البيانات (الصور والأسماء)
// =========================================================================
class OffersDataFetcher extends StatefulWidget {
  final String sellerId;
  const OffersDataFetcher({super.key, required this.sellerId});

  @override
  State<OffersDataFetcher> createState() => _OffersDataFetcherState();
}

class _OffersDataFetcherState extends State<OffersDataFetcher> {
  String _sellerName = "التاجر";
  late Future<List<Map<String, dynamic>>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _offersFuture = _loadOffersWithProductData();
  }

  Future<List<Map<String, dynamic>>> _loadOffersWithProductData() async {
    final db = FirebaseFirestore.instance;
    
    try {
      final sellerDoc = await db.collection("sellers").doc(widget.sellerId).get();
      if (sellerDoc.exists && mounted) {
        setState(() => _sellerName = sellerDoc.data()?['fullname'] ?? "التاجر");
      }
    } catch (e) {
      debugPrint("Error fetching seller name: $e");
    }

    final offersSnapshot = await db.collection("productOffers")
              .where("sellerId", isEqualTo: widget.sellerId)
              .get();
    
    if (offersSnapshot.docs.isEmpty) return [];

    final offersWithProducts = <Map<String, dynamic>>[];
    
    for (var offerDoc in offersSnapshot.docs) {
        final offerData = offerDoc.data();
        final productId = offerData['productId']?.toString();
        
        if (productId != null) {
            final productSnap = await db.collection("products").doc(productId).get();
            
            if (productSnap.exists) {
                final productData = productSnap.data()!;
                final List<dynamic>? imageUrls = productData['imageUrls'] as List<dynamic>?;
                
                // ✅ 3. حقن البيانات لضمان العرض المتكامل (صور + أسماء)
                offersWithProducts.add({
                    ...offerData, 
                    'offerDocId': offerDoc.id,
                    'productName': productData['name'] ?? 'منتج غير معروف',
                    'imageUrls': imageUrls, 
                });
            }
        }
    }
    return offersWithProducts;
  }

  void _openProductDetails(String offerDocId) {
    // ✅ تفعيل التوجيه لصفحة التفاصيل
    Navigator.of(context).pushNamed(
      ProductDetailsScreen.routeName,
      arguments: {'offerId': offerDocId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _offersFuture,
      builder: (context, snapshot) {
        
        final titleWidget = Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: AppTheme.primaryGreen, size: 28), 
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'عروض $_sellerName',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(children: [titleWidget, const Expanded(child: Center(child: CircularProgressIndicator()))]);
        }
        
        if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
          return Column(
            children: [
              titleWidget, 
              const Expanded(child: Center(child: Text('لا توجد عروض متاحة حالياً.'))),
            ],
          );
        }

        final offers = snapshot.data!;
        
        return Column(
          children: [
            titleWidget,
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
                  childAspectRatio: 0.68, 
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  final offer = offers[index];
                  return TraderOfferCard(
                    offerData: offer,
                    offerDocId: offer['offerDocId'],
                    onTap: () => _openProductDetails(offer['offerDocId']),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
