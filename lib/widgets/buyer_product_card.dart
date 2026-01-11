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

  // دالة الإضافة الأصلية (تم تعديلها لتقبل العرض والكمية كبارامترات)
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
          content: Text('✅ تمت إضافة $qty قطعة إلى السلة', style: GoogleFonts.cairo(fontSize: 12.sp, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final offersProvider = context.watch<ProductOffersProvider>();
    final selectedOffer = offersProvider.selectedOffer;
    final isLoadingOffers = offersProvider.isLoading;
    final availableOffers = offersProvider.availableOffers;

    final primaryColor = Theme.of(context).primaryColor;
    final displayImageUrl = widget.productData['imageUrls']?.isNotEmpty == true
        ? widget.productData['imageUrls'][0]
        : 'https://via.placeholder.com/300';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // تصغير الكارت ليلائم المحتوى
          children: [
            InkWell(
              onTap: () => widget.onTap?.call(widget.productId, selectedOffer?.offerId),
              child: Image.network(displayImageUrl, height: 12.h, fit: BoxFit.contain),
            ),
            const SizedBox(height: 5),
            Text(
              widget.productData['name'] ?? 'منتج غير معروف',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 14.sp),
            ),
            const SizedBox(height: 10),
            
            // الزر الخارجي المطور (يفتح المنبثقة فقط)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoadingOffers ? null : () => _showOfferSelectionModal(context, availableOffers, selectedOffer, offersProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                child: isLoadingOffers 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('🛒 عرض الأسعار والطلب', style: GoogleFonts.cairo(fontSize: 13.sp, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOfferSelectionModal(BuildContext context, List<OfferModel> availableOffers, OfferModel? selectedOffer, ProductOffersProvider provider) {
    if (availableOffers.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (modalContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(10, 20, 10, 20.sp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('اختيار العرض المناسب', style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              const Divider(),
              const SizedBox(height: 10),
              ...availableOffers.map((offer) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('${offer.sellerName} (${offer.unitName})', style: GoogleFonts.cairo(fontSize: 15.sp, fontWeight: FontWeight.bold))),
                            Text('${offer.price} ج', style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.red.shade700)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text('متوفر: ${offer.stock}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 15),
                            Text('أقل كمية: ${offer.minQty}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
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
                              flex: 1,
                              child: ElevatedButton(
                                onPressed: offer.stock == 0 ? null : () {
                                  _addToCart(offer, provider.currentQuantity);
                                  Navigator.pop(modalContext);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(vertical: 10)),
                                child: Text('أضف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.sp)),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}
