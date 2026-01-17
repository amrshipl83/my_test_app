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
  final String? offerId; // ✅ أعدناه هنا لمنع خطأ main.dart

  const ProductDetailsScreen({super.key, this.productId, this.offerId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Map<String, dynamic>? _productData;
  List<Map<String, dynamic>> _offers = [];
  bool _isLoading = true;
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
      // حتى لو تم تمرير offerId من main.dart، سنركز على productId لجلب كل العروض
    } else {
      _currentProductId = widget.productId;
    }
  }

  Future<void> _initializeData() async {
    try {
      if (_currentProductId == null || _currentProductId!.isEmpty) return;
      
      final results = await Future.wait([
        _db.collection('products').doc(_currentProductId).get(),
        _db.collection('productOffers').where('productId', isEqualTo: _currentProductId).get(),
      ]);

      final productDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final offersSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;

      if (productDoc.exists) {
        _productData = productDoc.data();
      }

      _offers = offersSnap.docs.map((doc) {
        final data = doc.data();
        double price = 0.0;
        String unit = "وحدة";
        int stock = 0;

        if (data['units'] != null && (data['units'] as List).isNotEmpty) {
          final first = data['units'][0];
          price = (first['price'] is num) ? first['price'].toDouble() : 0.0;
          unit = first['unitName'] ?? "وحدة";
          stock = (first['availableStock'] is num) ? first['availableStock'].toInt() : 0;
        }

        return {
          ...data,
          'offerId': doc.id,
          'displayPrice': price,
          'displayUnit': unit,
          'calculatedStock': stock,
        };
      }).toList();

    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addToCart(Map<String, dynamic> offer) async {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final String imageUrl = (_productData?['imageUrls'] as List?)?.isNotEmpty == true
          ? _productData!['imageUrls'][0] : '';

      await cartProvider.addItemToCart(
        offerId: offer['offerId'],
        productId: _currentProductId!,
        sellerId: offer['sellerId'] ?? '',
        sellerName: offer['sellerName'] ?? 'تاجر',
        name: _productData?['name'] ?? 'منتج',
        price: (offer['displayPrice'] as num).toDouble(),
        unit: offer['displayUnit'],
        unitIndex: 0,
        imageUrl: imageUrl,
        userRole: 'buyer',
        quantityToAdd: 1,
        mainId: _productData?['mainId'],
        subId: _productData?['subId'],
        availableStock: offer['calculatedStock'] ?? 0,
        minOrderQuantity: (offer['minOrder'] as num?)?.toInt() ?? 1,
        maxOrderQuantity: (offer['maxOrder'] as num?)?.toInt() ?? 9999,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تمت الإضافة للسلة'), backgroundColor: Colors.green)
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_productData?['name'] ?? 'التفاصيل', style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, _) => Badge(
          label: Text('${cart.cartTotalItems}'),
          isLabelVisible: cart.cartTotalItems > 0,
          child: FloatingActionButton(
            onPressed: () => Navigator.pushNamed(context, '/cart'),
            backgroundColor: AppTheme.primaryGreen,
            child: const Icon(Icons.shopping_cart, color: Colors.white),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildImageGallery(),
            Padding(
              padding: const EdgeInsets.all(16),
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

  Widget _buildImageGallery() {
    final images = (_productData?['imageUrls'] as List?) ?? [];
    if (images.isEmpty) return Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.image));
    return SizedBox(
      height: 250,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) => Image.network(images[index], fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildOfferItem(Map<String, dynamic> offer) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(offer['sellerName'] ?? 'تاجر', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        subtitle: Text('${offer['displayPrice']} ج.م / ${offer['displayUnit']}', style: GoogleFonts.cairo(color: Colors.red)),
        leading: ElevatedButton(
          onPressed: () => _addToCart(offer),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
          child: const Text('إضافة', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
