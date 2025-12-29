import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/services/marketplace_data_service.dart';
import 'package:my_test_app/models/product_model.dart';
import 'package:my_test_app/models/offer_model.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/screens/consumer/consumer_product_details_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart'; // استيراد الشريط الموحد

class ConsumerProductListScreen extends StatefulWidget {
  static const routeName = '/consumerProducts';

  final String ownerId;
  final String mainId;
  final String subId;
  final String subCategoryName;

  const ConsumerProductListScreen({
    super.key,
    required this.ownerId,
    required this.mainId,
    required this.subId,
    required this.subCategoryName,
  });

  @override
  State<ConsumerProductListScreen> createState() => _ConsumerProductListScreenState();
}

class _ConsumerProductListScreenState extends State<ConsumerProductListScreen> {
  final MarketplaceDataService _dataService = MarketplaceDataService();
  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _dataService.fetchProductsAndOffersBySubCategory(
      ownerId: widget.ownerId,
      mainId: widget.mainId,
      subId: widget.subId,
    );
  }

  // دالة الإضافة للسلة (نفس منطقك الأصلي دون تغيير)
  void _addToCart(BuildContext context, ProductModel product, ProductOfferModel offer) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (offer.units.isEmpty) return;
    final firstUnit = offer.units.first;

    try {
      await cartProvider.addItemToCart(
        productId: product.id,
        name: product.name,
        offerId: offer.id!,
        sellerId: offer.sellerId!,
        sellerName: offer.sellerName ?? 'متجر',
        unitIndex: 0,
        unit: firstUnit.unitName,
        price: firstUnit.price,
        quantityToAdd: 1,
        userRole: 'consumer',
        imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : '',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تمت الإضافة للسلة'), backgroundColor: Color(0xFF4CAF50), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF4a6491),
          foregroundColor: Colors.white,
          title: Text(widget.subCategoryName, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900)),
          centerTitle: true,
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final products = snapshot.data!;
            return GridView.builder(
              padding: EdgeInsets.all(4.w),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 4.w,
                mainAxisSpacing: 4.w,
                childAspectRatio: 0.68, // تحسين النسبة لتناسب الخطوط الكبيرة
              ),
              itemCount: products.length,
              itemBuilder: (context, index) => _buildEnhancedProductCard(context, products[index]),
            );
          },
        ),
        // استخدام الشريط السفلي الموحد لضمان التوجيه الصحيح
        bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: -1),
      ),
    );
  }

  Widget _buildEnhancedProductCard(BuildContext context, Map<String, dynamic> data) {
    final product = data['product'] as ProductModel;
    final offer = data['offer'] as ProductOfferModel;
    final price = offer.units.isNotEmpty ? offer.units.first.price : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            ConsumerProductDetailsScreen.routeName,
            arguments: {'productId': product.id, 'offerId': offer.id},
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج (تناسق كامل مع الإطار)
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    product.imageUrls.isNotEmpty ? product.imageUrls.first : 'https://via.placeholder.com/150',
                    fit: BoxFit.contain, // لضمان عدم قص الصورة
                  ),
                ),
              ),
            ),
            // المعلومات بخطوط واضحة
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: const Color(0xFF2D3142))),
                  SizedBox(height: 0.5.h),
                  Text("${price.toStringAsFixed(2)} ج.م",
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  SizedBox(height: 1.5.h),
                  // زر إضافة للسلة بشكل عصري
                  SizedBox(
                    width: double.infinity,
                    height: 5.h,
                    child: ElevatedButton(
                      onPressed: () => _addToCart(context, product, offer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_shopping_cart, size: 16, color: Colors.white),
                          SizedBox(width: 2.w),
                          Text("أضف", style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[300]),
          SizedBox(height: 2.h),
          Text("لا توجد منتجات حالياً في هذا القسم", style: TextStyle(color: Colors.grey, fontSize: 13.sp)),
        ],
      ),
    );
  }
}

