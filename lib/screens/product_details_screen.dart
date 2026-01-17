import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:my_test_app/theme/app_theme.dart';

final FirebaseFirestore _db = FirebaseFirestore.instance;

class ProductDetailsScreen extends StatefulWidget {
  static const routeName = '/productDetails';

  final String? productId;
  final String? offerId;

  const ProductDetailsScreen({
    super.key,
    this.productId,
    this.offerId,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Map<String, dynamic>? _productData;
  List<Map<String, dynamic>> _offers = [];
  bool _isLoadingProduct = true;
  bool _isLoadingOffers = true;
  String? _errorMessage;

  String? _currentProductId;
  String? _currentOfferId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _extractArgsAndLoad();
  }

  void _extractArgsAndLoad() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _currentProductId = args['productId']?.toString();
      _currentOfferId = args['offerId']?.toString();
    } else {
      _currentProductId = widget.productId;
      _currentOfferId = widget.offerId;
    }

    if (_isLoadingProduct) {
      _loadProductAndOffers();
    }
  }

  // 🛒 دالة الإضافة للسلة (نفس منطق الأصل)
  Future<void> _addToCart(Map<String, dynamic> offer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<dynamic> cart = [];
      String? cartData = prefs.getString('cart_items');
      
      if (cartData != null) {
        cart = jsonDecode(cartData);
      }

      // تجهيز بيانات المنتج بنفس مفاتيح السيستم
      final cartItem = {
        'productId': _currentProductId,
        'offerId': offer['id'],
        'sellerId': offer['sellerId'],
        'productName': _productData?['name'] ?? 'منتج',
        'price': offer['price'],
        'imageUrl': (_productData?['imageUrls'] as List?)?.first ?? '',
        'quantity': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      cart.add(cartItem);
      await prefs.setString('cart_items', jsonEncode(cart));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة المنتج للسلة بنجاح', textAlign: TextAlign.right),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint("Cart Error: $e");
    }
  }

  Future<Map<String, String>> _fetchSellerInfo(String sellerId) async {
    String sellerName = 'تاجر غير معروف';
    String sellerLogo = '';
    try {
      final sellerDoc = await _db.collection('sellers').doc(sellerId).get();
      if (sellerDoc.exists) {
        sellerName = sellerDoc.data()?['fullname'] ?? sellerDoc.data()?['name'] ?? sellerName;
        sellerLogo = sellerDoc.data()?['imageUrl'] ?? '';
      }
    } catch (e) { debugPrint('Seller Info Error: $e'); }
    return {'name': sellerName, 'logo': sellerLogo};
  }

  Future<void> _loadProductAndOffers() async {
    if (_currentProductId == null && _currentOfferId != null) {
      final offerSnap = await _db.collection('productOffers').doc(_currentOfferId).get();
      if (offerSnap.exists) _currentProductId = offerSnap.data()?['productId'];
    }

    if (_currentProductId == null) {
      setState(() { _errorMessage = 'لم يتم تحديد المنتج'; _isLoadingProduct = false; });
      return;
    }

    try {
      final productDoc = await _db.collection('products').doc(_currentProductId!).get();
      if (productDoc.exists) {
        _productData = productDoc.data();
      } else {
        _errorMessage = 'المنتج غير موجود';
      }
    } catch (e) { _errorMessage = 'خطأ في التحميل'; }
    finally { if (mounted) setState(() => _isLoadingProduct = false); }

    // تحميل العرض المحدد أو كل العروض
    if (_currentOfferId != null) {
      await _loadSpecificOffer(_currentOfferId!);
    } else {
      await _loadAllOffers(_currentProductId!);
    }
  }

  Future<void> _loadSpecificOffer(String offerId) async {
    try {
      final doc = await _db.collection('productOffers').doc(offerId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final sellerInfo = await _fetchSellerInfo(data['sellerId'] ?? '');
        if (mounted) setState(() => _offers = [{...data, 'id': doc.id, 'sellerInfo': sellerInfo}]);
      }
    } finally { if (mounted) setState(() => _isLoadingOffers = false); }
  }

  Future<void> _loadAllOffers(String productId) async {
    try {
      final snap = await _db.collection('productOffers').where('productId', isEqualTo: productId).get();
      List<Map<String, dynamic>> list = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        final sellerInfo = await _fetchSellerInfo(data['sellerId'] ?? '');
        list.add({...data, 'id': doc.id, 'sellerInfo': sellerInfo});
      }
      if (mounted) setState(() => _offers = list);
    } finally { if (mounted) setState(() => _isLoadingOffers = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProduct) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage != null) return Scaffold(body: Center(child: Text(_errorMessage!)));

    final images = List<String>.from(_productData?['imageUrls'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(_productData?['name'] ?? 'تفاصيل المنتج'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // معرض الصور
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                image: DecorationImage(
                  image: images.isNotEmpty ? NetworkImage(images.first) : const AssetImage('assets/placeholder.png') as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(_productData?['name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
            const SizedBox(height: 10),
            Text(_productData?['description'] ?? '', style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.right),
            const Divider(height: 40),
            const Text('العروض المتاحة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
            const SizedBox(height: 15),
            _isLoadingOffers 
              ? const Center(child: CircularProgressIndicator()) 
              : Column(children: _offers.map((o) => _buildOfferCard(o)).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final seller = offer['sellerInfo'] as Map<String, String>;
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(backgroundImage: seller['logo']!.isNotEmpty ? NetworkImage(seller['logo']!) : null),
              title: Text(seller['name']!, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('السعر: ${offer['price']} جنيه', textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addToCart(offer),
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                label: const Text('إضافة إلى السلة', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            )
          ],
        ),
      ),
    );
  }
}
