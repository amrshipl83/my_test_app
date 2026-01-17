import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/cart_provider.dart';

final FirebaseFirestore _db = FirebaseFirestore.instance;

class ProductDetailsScreen extends StatefulWidget {
  static const routeName = '/productDetails';
  final String? productId;
  final String? offerId;

  const ProductDetailsScreen({super.key, this.productId, this.offerId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Map<String, dynamic>? _productData;
  List<Map<String, dynamic>> _offers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentProductId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _extractArgs();
    if (_isLoading) _initializeData();
  }

  void _extractArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _currentProductId = args['productId']?.toString();
    } else {
      _currentProductId = widget.productId;
    }
  }

  Future<void> _initializeData() async {
    try {
      if (_currentProductId == null || _currentProductId!.isEmpty) throw 'معرف المنتج غير موجود';
      await Future.wait([_fetchProductDetails(), _fetchAllOffers()]);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProductDetails() async {
    final doc = await _db.collection('products').doc(_currentProductId!).get();
    if (doc.exists) _productData = doc.data();
  }

  Future<void> _fetchAllOffers() async {
    final snap = await _db.collection('productOffers')
        .where('productId', isEqualTo: _currentProductId)
        .get();

    _offers = snap.docs.map((doc) {
      final data = doc.data();
      double price = 0.0;
      String unit = "وحدة";
      
      if (data['units'] != null && (data['units'] as List).isNotEmpty) {
        final first = (data['units'] as List).first;
        price = (first['price'] is num) ? first['price'].toDouble() : 0.0;
        unit = first['unitName'] ?? "وحدة";
      }

      return {
        ...data,
        'offerId': doc.id,
        'displayPrice': price,
        'displayUnit': unit,
      };
    }).toList();
  }

  // ✅ الدالة المستقرة المنسوخة من كودك الناجح
  void _addToCart(Map<String, dynamic> offer, int qty) async {
    if (offer['offerId'] == null || qty == 0) return;
    
    final String imageUrl = (_productData?['imageUrls'] as List?)?.isNotEmpty == true
        ? _productData!['imageUrls'][0] : '';
        
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      
      await cartProvider.addItemToCart(
        productId: _currentProductId!,
        name: _productData?['name'] ?? 'منتج غير معروف',
        offerId: offer['offerId'],
        sellerId: offer['sellerId'],
        sellerName: offer['sellerName'],
        price: offer['displayPrice'].toDouble(), 
        unit: offer['displayUnit'],
        unitIndex: 0,
        quantityToAdd: qty,
        imageUrl: imageUrl,
        userRole: 'buyer',
        minOrderQuantity: offer['minQty'] ?? 1, // تأكدنا من الاسم minQty
        availableStock: offer['stock'] ?? 0,    // تأكدنا من الاسم stock
        maxOrderQuantity: offer['maxQty'] ?? 9999,
        mainId: _productData?['mainId'],
        subId: _productData?['subId'],
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم الإضافة للسلة', style: GoogleFonts.cairo()), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_productData?['name'] ?? 'التفاصيل', style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.primaryGreen,
      ),
      // أيقونة السلة العائمة الموحدة
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, child) => Badge(
          label: Text('${cart.cartTotalItems}'),
          isLabelVisible: cart.cartTotalItems > 0,
          child: FloatingActionButton(
            onPressed: () => Navigator.of(context).pushNamed('/cart'),
            backgroundColor: AppTheme.primaryGreen,
            child: const Icon(Icons.shopping_cart, color: Colors.white),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_productData?['imageUrls'] != null)
              Image.network(_productData!['imageUrls'][0], height: 250, fit: BoxFit.contain),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_productData?['name'] ?? '', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                  const Divider(),
                  ..._offers.map((offer) => Card(
                    child: ListTile(
                      title: Text(offer['sellerName'] ?? ''),
                      subtitle: Text('${offer['displayPrice']} ج.م / ${offer['displayUnit']}'),
                      leading: ElevatedButton(
                        onPressed: () => _addToCart(offer, 1),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                        child: const Text('إضافة', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  )).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
