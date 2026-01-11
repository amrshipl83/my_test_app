// lib/widgets/buyer_product_card.dart

@override
Widget build(BuildContext context) {
  final offersProvider = context.watch<ProductOffersProvider>();
  final isLoadingOffers = offersProvider.isLoading;
  final availableOffers = offersProvider.availableOffers;
  final bool hasOffers = availableOffers.isNotEmpty; // التأكد من وجود عروض

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
          // 1. جعل الصورة تأخذ المساحة المتاحة لملء الفراغ
          Expanded(
            child: InkWell(
              onTap: hasOffers 
                  ? () => widget.onTap?.call(widget.productId, offersProvider.selectedOffer?.offerId)
                  : null,
              child: Container(
                width: double.infinity,
                child: Image.network(
                  displayImageUrl, 
                  fit: BoxFit.contain, // يحافظ على تناسق الصورة
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
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800, 
              fontSize: 15.sp,
              height: 1.2,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 3. زر "عرض الأسعار" أو "لا توجد عروض"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // تعطيل الزر في حال التحميل أو عدم وجود عروض
              onPressed: (isLoadingOffers || !hasOffers) 
                  ? null 
                  : () => _showOfferSelectionModal(context, availableOffers, offersProvider.selectedOffer, offersProvider),
              style: ElevatedButton.styleFrom(
                // تغيير اللون بناءً على الحالة
                backgroundColor: !hasOffers ? Colors.grey.shade400 : const Color(0xFFFF7000),
                disabledBackgroundColor: Colors.grey.shade300,
                padding: EdgeInsets.symmetric(vertical: 12.sp),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: !hasOffers ? 0 : 2,
              ),
              child: isLoadingOffers
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          !hasOffers ? Icons.block : Icons.shopping_cart_outlined, 
                          size: 16.sp, 
                          color: Colors.white
                        ),
                        SizedBox(width: 5.sp),
                        Text(
                          !hasOffers ? 'لا توجد عروض حالياً' : 'عرض الأسعار والطلب',
                          style: GoogleFonts.cairo(
                            fontSize: 13.sp, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.white
                          ),
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
