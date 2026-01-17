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

  Future<void> _addToCart(Map<String, dynamic> offer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<dynamic> cart = [];
      String? cartData = prefs.getString('cart_items');
      
      if (cartData != null) {
        cart = jsonDecode(cartData);
      }

      final cartItem = {
        'productId': _currentProductId,
        'offerId': offer['id'],
        'sellerId': offer['sellerId'] ?? '',
        'productName': _productData?['name'] ?? 'منتج',
        'price': offer['price'] ?? 0.0,
        'imageUrl': (_productData?['imageUrls'] as List?)?.isNotEmpty == true 
                    ? (_productData?['imageUrls'] as List).first 
                    : '',
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
    if (sellerId.isEmpty) return {'name': sellerName, 'logo': sellerLogo};
    
    try {
      final sellerDoc = await _db.collection('sellers').doc(sellerId).get();
      if (sellerDoc.exists) {
        final data = sellerDoc.data();
        sellerName = data?['fullname'] ?? data?['name'] ?? sellerName;
        sellerLogo = data?['imageUrl'] ?? '';
      }
    } catch (e) { debugPrint('Seller Info Error: $e'); }
    return {'name': sellerName, 'logo': sellerLogo};
  }

  Future<void> _loadProductAndOffers() async {
    if (_currentProductId == null && _currentOfferId != null) {
      try {
        final offerSnap = await _db.collection('productOffers').doc(_currentOfferId).get();
        if (offerSnap.exists) {
          _currentProductId = offerSnap.data()?['productId'];
        }
      } catch (e) { debugPrint("Error linking: $e"); }
    }

    if (_currentProductId == null) {
      if (mounted) setState(() { _errorMessage = 'لم يتم تحديد المنتج'; _isLoadingProduct = false; });
      return;
    }

    try {
      final productDoc = await _db.collection('products').doc(_currentProductId!).get();
      if (productDoc.exists) {
        _productData = productDoc.data();
      } else {
        _errorMessage = 'المنتج غير موجود';
      }
    } catch (e) { _errorMessage = 'خطأ في تحميل المنتج'; }
    finally { if (mounted) setState(() => _isLoadingProduct = false); }

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
        if (mounted) {
          setState(() {
            _offers = [{
              ...data, 
              'id': doc.id, 
              'sellerInfo': sellerInfo,
              'price': data['price'] ?? 0.0
            }];
          });
        }
      } else {
         if (mounted) setState(() => _errorMessage = "العرض غير متوفر");
      }
    } catch (e) { debugPrint("Specific Offer Error: $e"); }
    finally { if (mounted) setState(() => _isLoadingOffers = false); }
  }

  Future<void> _loadAllOffers(String productId) async {
    try {
      final snap = await _db.collection('productOffers').where('productId', isEqualTo: productId).get();
      List<Map<String, dynamic>> list = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        final sellerInfo = await _fetchSellerInfo(data['sellerId'] ?? '');
        list.add({
          ...data, 
          'id': doc.id, 
          'sellerInfo': sellerInfo,
          'price': data['price'] ?? 0.0
        });
      }
      if (mounted) setState(() => _offers = list);
    } catch (e) { debugPrint("All Offers Error: $e"); }
    finally { if (mounted) setState(() => _isLoadingOffers = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProduct) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppTheme.primaryGreen),
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 10),
            Text(_errorMessage!, style: const TextStyle(fontSize: 18)),
          ],
        )),
      );
    }

    final images = (_productData?['imageUrls'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_productData?['name'] ?? 'تفاصيل المنتج'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingOffers && _offers.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (images.isNotEmpty)
                  Container(
                    height: 250,
                    margin: const EdgeInsets.only(bottom: 20), // ✅ تم التصحيح هنا
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      image: DecorationImage(image: NetworkImage(images.first), fit: BoxFit.cover),
                    ),
                  )
                else
                  Container(
                    height: 150,
                    margin: const EdgeInsets.only(bottom: 20), // ✅ تم التصحيح هنا
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                  ),

                Text(_productData?['name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                const SizedBox(height: 10),
                Text(_productData?['description'] ?? '', style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.right),
                const Divider(height: 40),
                const Text('العروض المتوفرة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                const SizedBox(height: 15),
                
                ..._offers.map((o) => _buildOfferCard(o)).toList(),
              ],
            ),
          ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final seller = offer['sellerInfo'] as Map<String, String>;
    final price = offer['price']?.toString() ?? '0.0';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$price ج.م', style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text(seller['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    CircleAvatar(radius: 20, backgroundImage: seller['logo']!.isNotEmpty ? NetworkImage(seller['logo']!) : null, child: seller['logo']!.isEmpty ? const Icon(Icons.store) : null),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addToCart(offer),
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 20),
                label: const Text('أضف للسلة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen, 
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
