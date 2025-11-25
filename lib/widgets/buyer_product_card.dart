// المسار: lib/widgets/buyer_product_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/widgets/quantity_control.dart';
import 'package:google_fonts/google_fonts.dart'; // 💡 استدعاء Google Fonts

import 'package:my_test_app/utils/offer_data_model.dart';
import 'package:my_test_app/providers/product_offers_provider.dart';

class BuyerProductCard extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const BuyerProductCard({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  State<BuyerProductCard> createState() => _BuyerProductCardState();
}

class _BuyerProductCardState extends State<BuyerProductCard> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductOffersProvider>(context, listen: false)
          .fetchOffers(widget.productId);
    });
  }

  // 💥💥 التصحيح الأول: نقل الدالة لداخل الـ State Class 💥💥
  // 💡 دالة تغيير الكمية لتستدعي الـ Provider
  void _onQuantityChanged(int newQty) {
    Provider.of<ProductOffersProvider>(context, listen: false)
        .updateQuantity(newQty);
  }

  // 💥💥 التصحيح الثاني: نقل الدالة لداخل الـ State Class 💥💥
  // 💡 دالة الإضافة للسلة لاستخدام بيانات الـ Provider
  void _addToCart() {
    final offersProvider = Provider.of<ProductOffersProvider>(context, listen: false);
    final selectedOffer = offersProvider.selectedOffer;
    final currentQuantity = offersProvider.currentQuantity;

    if (selectedOffer == null || currentQuantity == 0) return;

    // 💥 هنا يجب تطبيق منطق حفظ السلة
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إضافة ${currentQuantity} من ${widget.productData['name']} إلى السلة.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final offersProvider = context.watch<ProductOffersProvider>();
    final selectedOffer = offersProvider.selectedOffer;
    final currentQuantity = offersProvider.currentQuantity;
    final isLoadingOffers = offersProvider.isLoading;
    final availableOffers = offersProvider.availableOffers;

    final imageUrl = widget.productData['imageUrls']?.isNotEmpty == true
        ? widget.productData['imageUrls'][0]
        : 'https://via.placeholder.com/300/0f3460/f0f0f0?text=لا توجد صورة';

    final bool isAddToCartDisabled = selectedOffer == null || currentQuantity < (selectedOffer.minQty ?? 1);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. الصورة الدائرية
            InkWell(
              onTap: () {
                // يجب تعريف مسار /productDetails
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).primaryColor, width: 3),
                  boxShadow: [
                    BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.1), blurRadius: 8)
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.shopping_bag, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 2. اسم المنتج
            Text(
              widget.productData['name'] ?? 'منتج غير معروف',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),

            // 3. اختيار العرض
            const SizedBox(height: 5),
            isLoadingOffers
                ? const LinearProgressIndicator()
                : InkWell(
                    onTap: () {
                      _showOfferSelectionModal(context, availableOffers, selectedOffer, offersProvider);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              selectedOffer == null
                                ? 'لا عروض متاحة'
                                : '${selectedOffer.price} ج - ${selectedOffer.unitName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selectedOffer == null ? Colors.red : Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

            const SizedBox(height: 8),

            // 4. التحكم في الكمية
            QuantityControl(
              initialQuantity: currentQuantity,
              minQuantity: selectedOffer?.minQty ?? 1,
              maxStock: selectedOffer?.stock ?? 0,
              onQuantityChanged: _onQuantityChanged, // ✅ تم تصحيح الـ Getter هنا
              isDisabled: selectedOffer == null || selectedOffer.stock == 0,
            ),

            // 5. زر الإضافة إلى السلة 💡 تحسين التصميم والخط
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isAddToCartDisabled ? null : _addToCart, // ✅ تم تصحيح الـ Getter هنا
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: Text(
                  'أضف إلى السلة',
                  style: GoogleFonts.notoSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.bold
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAddToCartDisabled ? Colors.grey : Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 💥 دالة عرض نموذج اختيار العرض (BottomSheet) - تصميم احترافي و Text.rich
  void _showOfferSelectionModal(BuildContext context, List<OfferModel> availableOffers, OfferModel? selectedOffer, ProductOffersProvider provider) {
    if (availableOffers.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            top: 10,
            left: 5,
            right: 5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
                child: Text(
                  'اختيار عرض المنتج',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(),

              // قائمة العروض بتصميم البطاقات
              ...availableOffers.map((offer) {
                final isSelected = offer.offerId == selectedOffer?.offerId && offer.unitIndex == selectedOffer?.unitIndex;
                final bool isDisabled = offer.disabled;

                return Card(
                  elevation: isSelected ? 4 : 1,
                  color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: InkWell(
                    onTap: isDisabled
                        ? null
                        : () {
                            provider.selectOffer(offer);
                            Navigator.pop(modalContext);
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. الوحدة والبائع
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${offer.unitName} - ${offer.sellerName}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDisabled ? Colors.grey : Colors.black,
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, color: Theme.of(context).primaryColor, size: 24),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // 2. السعر والمخزون
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'السعر: ', style: TextStyle(fontWeight: FontWeight.normal, color: Colors.grey)),
                                TextSpan(text: '${offer.price} ج', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary, fontSize: 16)),
                                const TextSpan(text: ' | ', style: TextStyle(color: Colors.grey)),
                                const TextSpan(text: 'متوفر: ', style: TextStyle(fontWeight: FontWeight.normal, color: Colors.grey)),
                                TextSpan(
                                  text: '${offer.stock}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: offer.stock > 0 ? Colors.green.shade600 : Colors.red.shade600,
                                  )
                                ),
                                const TextSpan(text: ' | الحد الأدنى: ', style: TextStyle(color: Colors.grey)),
                                TextSpan(text: '${offer.minQty}'),
                              ]
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
