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
  String? _currentOfferId;

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
      _currentOfferId = args['offerId']?.toString();
    } else {
      _currentProductId = widget.productId;
      _currentOfferId = widget.offerId;
    }
  }

  Future<void> _initializeData() async {
    try {
      if ((_currentProductId == null || _currentProductId!.isEmpty) && _currentOfferId != null) {
        final offerDoc = await _db.collection('productOffers').doc(_currentOfferId).get();
        if (offerDoc.exists) {
          _currentProductId = offerDoc.data()?['productId']?.toString();
        }
      }

      if (_currentProductId == null || _currentProductId!.isEmpty) {
        throw 'عذراً، لم نتمكن من العثور على معرف المنتج';
      }

      await Future.wait([
        _fetchProductDetails(),
        _fetchAllOffers(),
      ]);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProductDetails() async {
    final doc = await _db.collection('products').doc(_currentProductId!).get();
    if (doc.exists) {
      _productData = doc.data();
    } else {
      throw 'المنتج غير موجود';
    }
  }

  Future<void> _fetchAllOffers() async {
    final snap = await _db.collection('productOffers')
        .where('productId', isEqualTo: _currentProductId)
        .get();

    List<Map<String, dynamic>> temp = [];
    for (var doc in snap.docs) {
      final data = doc.data();
      double extractedPrice = 0.0;
      String unitName = "وحدة";
      
      if (data['units'] != null && (data['units'] as List).isNotEmpty) {
        final firstUnit = (data['units'] as List).first;
        extractedPrice = _parsePrice(firstUnit['price']);
        unitName = firstUnit['unitName']?.toString() ?? "وحدة";
      } else {
        extractedPrice = _parsePrice(data['price']);
      }

      temp.add({
        ...data,
        'id': doc.id,
        'displayPrice': extractedPrice,
        'displayUnit': unitName,
        'sellerName': data['sellerName'] ?? 'تاجر غير معروف',
      });
    }
    _offers = temp;
  }

  double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is num) return price.toDouble();
    return double.tryParse(price.toString()) ?? 0.0;
  }

  // ✅ الدالة المحدثة لتستخدم البروفايدر (نفس منطق الكود السابق)
  void _addToCart(Map<String, dynamic> offer) async {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final String imageUrl = (_productData?['imageUrls'] as List?)?.isNotEmpty == true
          ? _productData!['imageUrls'][0]
          : '';

      await cartProvider.addItemToCart(
        productId: _currentProductId!,
        name: _productData?['name'] ?? 'منتج غير معروف',
        offerId: offer['id'],
        sellerId: offer['sellerId'],
        sellerName: offer['sellerName'],
        price: offer['displayPrice'],
        unit: offer['displayUnit'],
        quantityToAdd: 1, // الكمية الافتراضية
        imageUrl: imageUrl,
        userRole: 'buyer',
        availableStock: offer['stock'] ?? 0,
        minOrderQuantity: offer['minOrder'] ?? 1,
        maxOrderQuantity: offer['maxOrder'] ?? 9999,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تمت الإضافة للسلة', style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_productData?['name'] ?? 'تفاصيل المنتج', style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      
      // ✅ أيقونة السلة العائمة الموحدة
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          final cartCount = cartProvider.cartTotalItems;
          return Stack(
            alignment: Alignment.topRight,
            children: [
              FloatingActionButton(
                onPressed: () => Navigator.of(context).pushNamed('/cart'),
                backgroundColor: const Color(0xFFFF7000), // لون برتقالي لتمييزها أو الأخضر حسب رغبتك
                child: const Icon(Icons.shopping_cart, color: Colors.white),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
            ],
          );
        },
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProductHeader(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_productData?['name'] ?? '', style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                  const SizedBox(height: 8),
                  Text(_productData?['description'] ?? '', style: GoogleFonts.cairo(color: Colors.grey), textAlign: TextAlign.right),
                  const Divider(height: 40),
                  Text('العروض المتاحة', style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                  const SizedBox(height: 12),
                  if (_offers.isEmpty)
                    const Center(child: Text('لا توجد عروض حالياً'))
                  else
                    ..._offers.map((offer) => _buildOfferItem(offer)).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    final imageUrl = (_productData?['imageUrls'] as List?)?.first;
    return Container(
      height: 250,
      width: double.infinity,
      color: Colors.white,
      child: imageUrl != null 
          ? Image.network(imageUrl, fit: BoxFit.contain)
          : const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),
    );
  }

  Widget _buildOfferItem(Map<String, dynamic> offer) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            ElevatedButton(
              onPressed: () => _addToCart(offer),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('إضافة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(offer['sellerName'], style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12.sp)),
                Text('الوحدة: ${offer['displayUnit']}', style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey)),
                Text('${offer['displayPrice']} ج.م', style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 13.sp)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
