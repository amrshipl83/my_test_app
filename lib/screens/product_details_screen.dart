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
      // 1. إذا كان المنتج غير موجود، نحاول استخراجه من العرض (كما في صور Firestore)
      if ((_currentProductId == null || _currentProductId!.isEmpty) && _currentOfferId != null) {
        final offerDoc = await _db.collection('productOffers').doc(_currentOfferId).get();
        if (offerDoc.exists) {
          _currentProductId = offerDoc.data()?['productId']?.toString();
        }
      }

      if (_currentProductId == null || _currentProductId!.isEmpty) {
        throw 'عذراً، لم نتمكن من العثور على معرف المنتج';
      }

      // 2. جلب البيانات
      await Future.wait([
        _fetchProductDetails(),
        _fetchAllOffers(), // نجلب كل عروض هذا المنتج من كل التجار
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
      throw 'المنتج غير موجود في قائمة المنتجات';
    }
  }

  Future<void> _fetchAllOffers() async {
    // البحث في مجموعة productOffers عن كل الوثائق التي تملك productId المطلوب
    final snap = await _db.collection('productOffers')
        .where('productId', isEqualTo: _currentProductId)
        .get();

    List<Map<String, dynamic>> temp = [];
    for (var doc in snap.docs) {
      final data = doc.data();
      
      // ✅ استخراج السعر من مصفوفة units (كما يظهر في صورتك)
      double extractedPrice = 0.0;
      String unitName = "وحدة";
      
      if (data['units'] != null && (data['units'] as List).isNotEmpty) {
        final firstUnit = (data['units'] as List).first;
        extractedPrice = _parsePrice(firstUnit['price']);
        unitName = firstUnit['unitName']?.toString() ?? "وحدة";
      } else {
        // فحص في حال وجود حقل سعر مباشر (للتوافق)
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

  Future<void> _addToCart(Map<String, dynamic> offer) async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> cart = jsonDecode(prefs.getString('cart_items') ?? '[]');

    cart.add({
      'productId': _currentProductId,
      'offerId': offer['id'],
      'sellerId': offer['sellerId'],
      'sellerName': offer['sellerName'],
      'productName': _productData?['name'] ?? offer['productName'],
      'price': offer['displayPrice'],
      'unit': offer['displayUnit'],
      'imageUrl': (_productData?['imageUrls'] as List?)?.first ?? offer['imageUrl'] ?? '',
      'quantity': 1,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await prefs.setString('cart_items', jsonEncode(cart));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الإضافة للسلة'), backgroundColor: AppTheme.primaryGreen)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppTheme.primaryGreen),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text('⚠️ $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          ),
        ),
      );
    }

    final imageUrl = (_productData?['imageUrls'] as List?)?.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(_productData?['name'] ?? 'تفاصيل المنتج'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // صورة المنتج
            if (imageUrl != null)
              Image.network(imageUrl, height: 300, width: double.infinity, fit: BoxFit.contain)
            else
              Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.image_not_supported, size: 50)),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_productData?['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_productData?['description'] ?? '', style: const TextStyle(color: Colors.grey), textAlign: TextAlign.right),
                  const Divider(height: 30),
                  const Text('عروض التجار المتاحة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  if (_offers.isEmpty)
                    const Center(child: Text('لا توجد عروض متوفرة حالياً لهذا المنتج'))
                  else
                    ..._offers.map((offer) => _buildOfferCard(offer)).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(offer['sellerName'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('الوحدة: ${offer['displayUnit']}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${offer['displayPrice']} ج.م', style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: () => _addToCart(offer),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(80, 30)
              ),
              child: const Text('طلب'),
            ),
          ],
        ),
      ),
    );
  }
}
