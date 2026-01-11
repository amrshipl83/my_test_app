// lib/widgets/buyer_product_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/widgets/quantity_control.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_test_app/utils/offer_data_model.dart';
import 'package:my_test_app/providers/product_offers_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:sizer/sizer.dart';

class BuyerProductCard extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final Function(String productId, String? offerId)? onTap;

  const BuyerProductCard({
    super.key,
    required this.productId,
    required this.productData,
    this.onTap,
  });

  @override
  State<BuyerProductCard> createState() => _BuyerProductCardState();
}

class _BuyerProductCardState extends State<BuyerProductCard> {
  static const String currentUserRole = 'buyer';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductOffersProvider>(context, listen: false)
          .fetchOffers(widget.productId);
    });
  }

  void _addToCart(OfferModel offer, int qty) async {
    if (offer == null || qty == 0) return;
    final String imageUrl = widget.productData['imageUrls']?.isNotEmpty == true
        ? widget.productData['imageUrls'][0]
        : '';
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.addItemToCart(
        productId: widget.productId,
        name: widget.productData['name'] ?? 'منتج غير معروف',
        offerId: offer.offerId!,
        sellerId: offer.sellerId!,
        sellerName: offer.sellerName!,
        price: offer.price.toDouble(), 
        unit: offer.unitName,
        unitIndex: offer.unitIndex ?? 0,
        quantityToAdd: qty,
        imageUrl: imageUrl,
        userRole: currentUserRole,
        minOrderQuantity: offer.minQty ?? 1,
        availableStock: offer.stock ?? 0,
        maxOrderQuantity: offer.maxQty ?? 9999,
        mainId: widget.productData['mainId'],
        subId: widget.productData['subId'],
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم الإضافة للسلة', style: GoogleFonts.cairo(fontSize: 14.sp)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final offersProvider = context.watch<ProductOffersProvider>();
    final isLoadingOffers = offersProvider.isLoading;
    final availableOffers = offersProvider.availableOffers;
    final hasOffers = availableOffers.isNotEmpty;

    final displayImageUrl = widget.productData['imageUrls']?.isNotEmpty == true
        ? widget.productData['imageUrls'][0]
        : 'https://via.placeholder.com/300';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: EdgeInsets.all(4.sp),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            // صورة المنتج تأخذ المساحة المتاحة لملء الفراغ
            Expanded(
              child: InkWell(
                onTap: hasOffers 
                    ? () => widget.onTap?.call(widget.productId, offersProvider.selectedOffer?.offerId)
                    : null,
                child: Image.network(displayImageUrl, fit: BoxFit.contain, width: double.infinity),
              ),
            ),
            const SizedBox(height: 8),
            // اسم المنتج
            Text(
              widget.productData['name'] ?? 'منتج غير معروف',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15.sp),
            ),
            const SizedBox(height: 12),
            // الزر المطور
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isLoadingOffers || !hasOffers) 
                    ? null 
                    : () => _showOfferSelectionModal(context, availableOffers, offersProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: !hasOffers ? Colors.grey : const Color(0xFFFF7000),
                  padding: EdgeInsets.symmetric(vertical: 12.sp),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isLoadingOffers
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(hasOffers ? Icons.shopping_cart_outlined : Icons.block, color: Colors.white, size: 16.sp),
                          const SizedBox(width: 8),
                          Text(
                            hasOffers ? 'عرض الأسعار والطلب' : 'لا توجد عروض حالياً',
                            style: GoogleFonts.cairo(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOfferSelectionModal(BuildContext context, List<OfferModel> availableOffers, ProductOffersProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (modalContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(15, 20, 15, 30.sp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('اختيار العرض والطلب', style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: availableOffers.map((offer) {
                      final bool isOutOfStock = (offer.stock ?? 0) <= 0;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text('${offer.sellerName} (${offer.unitName})', style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold))),
                                  Text('${offer.price} ج', style: GoogleFonts.cairo(fontSize: 19.sp, fontWeight: FontWeight.w900, color: Colors.red.shade700)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _tag("متوفر: ${offer.stock}", isOutOfStock ? Colors.red : Colors.green),
                                  const SizedBox(width: 8),
                                  _tag("أقل طلب: ${offer.minQty}", Colors.blueGrey),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: QuantityControl(
                                      initialQuantity: provider.currentQuantity < (offer.minQty ?? 1) ? (offer.minQty ?? 1) : provider.currentQuantity,
                                      minQuantity: offer.minQty ?? 1,
                                      maxStock: offer.stock ?? 0,
                                      onQuantityChanged: (qty) => provider.updateQuantity(qty),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: isOutOfStock ? null : () {
                                        _addToCart(offer, provider.currentQuantity);
                                        Navigator.pop(modalContext);
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800),
                                      child: Text('أضف', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: GoogleFonts.cairo(fontSize: 12.sp, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
