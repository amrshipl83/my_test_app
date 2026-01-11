// المسار: lib/widgets/buyer_product_card.dart
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

  // دالة الإضافة الأصلية مع الحفاظ على كافة البارامترات لضمان عمل الكاش باك
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
          content: Text(
            '✅ تمت إضافة $qty من ${widget.productData['name']} للسلة',
            style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final offersProvider = context.watch<ProductOffersProvider>();
    final selectedOffer = offersProvider.selectedOffer;
    final isLoadingOffers = offersProvider.isLoading;
    final availableOffers = offersProvider.availableOffers;

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
          mainAxisSize: MainAxisSize.min, // لجعل الكارت مضغوطاً وأنيقاً
          children: [
            // صورة المنتج
            InkWell(
              onTap: () => widget.onTap?.call(widget.productId, selectedOffer?.offerId),
              child: Image.network(displayImageUrl, height: 13.h, fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            
            // اسم المنتج بخط عريض وكبير
            Text(
              widget.productData['name'] ?? 'منتج غير معروف',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15.sp),
            ),
            
            const Spacer(), // دفع الزر لأسفل الكارت تماماً
            
            // الزر البرتقالي الجديد (عرض الأسعار والطلب)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoadingOffers 
                    ? null 
                    : () => _showOfferSelectionModal(context, availableOffers, selectedOffer, offersProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7000), // لون برتقالي مميز
                  padding: EdgeInsets.symmetric(vertical: 12.sp),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                child: isLoadingOffers
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 16.sp, color: Colors.white),
                          SizedBox(width: 5.sp),
                          Text(
                            'عرض الأسعار والطلب',
                            style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.white),
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

  void _showOfferSelectionModal(BuildContext context, List<OfferModel> availableOffers, OfferModel? selectedOffer, ProductOffersProvider provider) {
    if (availableOffers.isEmpty) return;
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
              Text(
                'اختيار عرض المنتج والطلب',
                style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              const Divider(thickness: 1.5),
              const SizedBox(height: 10),
              
              // قائمة العروض داخل المنبثقة
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: availableOffers.map((offer) {
                      final bool isOutOfStock = (offer.stock ?? 0) <= 0;
                      
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // اسم التاجر والسعر
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${offer.sellerName} (${offer.unitName})',
                                      style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    '${offer.price} ج',
                                    style: GoogleFonts.cairo(fontSize: 20.sp, fontWeight: FontWeight.w900, color: Colors.red.shade700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // الحد الأدنى والمخزن
                              Row(
                                children: [
                                  _buildTag("متوفر: ${offer.stock}", isOutOfStock ? Colors.red : Colors.green),
                                  const SizedBox(width: 10),
                                  _buildTag("أقل طلب: ${offer.minQty}", Colors.blueGrey),
                                ],
                              ),
                              
                              const SizedBox(height: 15),
                              
                              // التحكم في الكمية + زر أضف
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: QuantityControl(
                                      initialQuantity: provider.currentQuantity < (offer.minQty ?? 1) ? (offer.minQty ?? 1) : provider.currentQuantity,
                                      minQuantity: offer.minQty ?? 1,
                                      maxStock: offer.stock ?? 0,
                                      onQuantityChanged: (qty) => provider.updateQuantity(qty),
                                      isDisabled: isOutOfStock,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 1,
                                    child: ElevatedButton(
                                      onPressed: isOutOfStock ? null : () {
                                        _addToCart(offer, provider.currentQuantity);
                                        Navigator.pop(modalContext);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2E7D32), // لون أخضر غامق للإضافة
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: Text(
                                        'أضف',
                                        style: GoogleFonts.cairo(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
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

  // ودجت صغيرة لعرض البيانات (المخزن والحد الأدنى) بشكل منسق
  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(fontSize: 13.sp, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
