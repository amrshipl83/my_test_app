// المسار: lib/screens/buyer/cart_screen.dart
                                                import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// 💡 [تصحيح] التأكد من مسار الـ Provider والـ Widget باستخدام اسم الحزمة الحالي (my_test_app)
import 'package:my_test_app/providers/cart_provider.dart';                                      import 'package:my_test_app/widgets/cart/cart_item_card.dart';

// 🎨 تعريف الألوان بناءً على CSS
const Color kPrimaryColor = Color(0xFF3bb77e);
const Color kErrorColor = Color(0xFFDC3545);
const Color kClearButtonColor = Color(0xFFff7675);
const Color kDeliverySummaryBg = Color(0xFFE0F7FA);
const Color kDeliverySummaryText = Color(0xFF00838f);
const Color kWarningMessageBg = Color(0xFFfff3cd);
const Color kWarningMessageBorder = Color(0xFFffc107);
const Color kWarningMessageText = Color(0xFF856404);
// 🆕 [تصحيح] إضافة الثابت المفقود الذي تم استخدامه في _buildDeliverySummary
const Color kGiftBorderColor = Color(0xFF00838f); // استخدام نفس لون النص ليكون متناسقاً

class CartScreen extends StatefulWidget {
  // 💡 يمكن تعريف اسم المسار هنا للاستخدام لاحقاً في main.dart
  static const String routeName = '/cart';
  
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}
                                               
class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // 💡 تحميل البيانات وحساب الإجماليات عند فتح الشاشة
    // يجب استبدال 'consumer' بدور المستخدم الفعلي
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(context, listen: false).loadCartAndRecalculate('consumer');
    });
  }
                                             
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة التسوق', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white, // يجب توحيد لون الـ AppBar مع التصميم العام
      ),
      // 💡 استخدام Consumer للاستماع لتغيرات الـ Provider
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.isCartEmpty) {
            return _buildEmptyCart();
          }

          // قائمة بـ Ids البائعين لضمان ترتيب العرض
          final sellerIds = cartProvider.sellersOrders.keys.toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 💡 بناء أقسام السلة حسب البائع (محاكاة دقيقة)
                ...sellerIds.map((sellerId) {
                  final sellerData = cartProvider.sellersOrders[sellerId]!;
                  return _buildSellerOrderSection(context, sellerData);
                }).toList(),
                                                                                    const SizedBox(height: 25),
                                                                // 💡 ملخص رسوم التوصيل
                if (cartProvider.totalDeliveryFees > 0)
                  _buildDeliverySummary(cartProvider.totalDeliveryFees),
                        
                const SizedBox(height: 15),
                                                                     // 💡 الإجمالي الكلي
                _buildTotalContainer(cartProvider.finalTotal),
                                  
                const SizedBox(height: 20),     
                // 💡 أزرار التحكم
                _buildActionButtons(context, cartProvider),
                                                   ],
            ),
          );
        },
      ),
    );
  }
                                                  // ------------------------------------------
  // 💡 مكونات واجهة المستخدم (Widgets)
  // ------------------------------------------

  // محاكاة لـ .empty-cart
  Widget _buildEmptyCart() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              'سلة التسوق فارغة',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // محاكاة لمنطق عرض الطلب المجمع حسب البائع (يشمل التحذيرات وعناصر الهدايا)
  Widget _buildSellerOrderSection(BuildContext context, SellerOrderData sellerData) {
    // 1. رسالة تحذير الحد الأدنى (Min Order Status)
    final bool isMinOrderMet = sellerData.isMinOrderMet;

    // 2. الهدايا المستحقة (Gifts) - إذا تحقق الحد الأدنى
    final List<Widget> giftsWidgets = [];
    if (isMinOrderMet && sellerData.giftedItems.isNotEmpty) {
      // final giftNames = sellerData.giftedItems.map((g) => '${g.quantity} ${g.unit} ${g.name}').join(' و '); // تم التعليق لعدم الاستخدام
      giftsWidgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 20.0, top: 10.0),
          child: CartItemCard(
            item: sellerData.giftedItems.first, // عرض الهدية الأولى كنموذج
            isWarning: false,
          ),
        ),
      );
    }

    // 3. قائمة المنتجات
    final List<Widget> itemWidgets = sellerData.items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;

      // 💡 [ملاحظة]: نحتاج طريقة لتحديد خطأ المخزون الفعلي، هنا نستخدم قيمة وهمية الآن
      final String? itemError = sellerData.hasProductErrors && index == 0 ? "الحد الأقصى هو 5 وحدات." : null;

      return CartItemCard(
        item: item,
        isWarning: !isMinOrderMet,
        itemError: itemError,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. رسالة الحد الأدنى (Min Order Link/Success)
        _buildMinOrderWarning(
          context,
          isMinOrderMet: isMinOrderMet,
          sellerName: sellerData.sellerName,
          message: sellerData.minOrderAlert ?? '',
        ),
                                                        // 2. الهدايا
        ...giftsWidgets,

        // 3. المنتجات الفعلية
        ...itemWidgets,

        const Divider(thickness: 1, height: 30),
      ],
    );
  }

  // محاكاة لـ .warning-message
  Widget _buildMinOrderWarning(BuildContext context, {
    required bool isMinOrderMet,
    required String sellerName,
    required String message,
  }) {
    Color bgColor = isMinOrderMet ? Colors.green.shade50 : kWarningMessageBg;
    Color borderColor = isMinOrderMet ? kPrimaryColor : kWarningMessageBorder;
    Color textColor = isMinOrderMet ? Colors.green.shade800 : kWarningMessageText;
    Color linkColor = isMinOrderMet ? kPrimaryColor : kErrorColor;
    String linkText = isMinOrderMet ? 'عروض $sellerName المميزة' : 'أكمل طلبك من $sellerName';
    IconData icon = isMinOrderMet ? Icons.check_circle : Icons.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: borderColor, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: borderColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: TextStyle(color: textColor, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 💡 محاكاة لـ .min-order-link
          GestureDetector(
            onTap: () {
              // توجيه لصفحة عروض التاجر
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('الانتقال إلى عروض $sellerName...')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: linkColor, width: 1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isMinOrderMet ? Icons.tag : Icons.add_circle, color: linkColor, size: 16),
                  const SizedBox(width: 5),
                  Text(linkText, style: TextStyle(color: linkColor, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // محاكاة لـ .delivery-summary
  Widget _buildDeliverySummary(double fee) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: kDeliverySummaryBg,
        borderRadius: BorderRadius.circular(8),
        // 💡 استخدام kGiftBorderColor الذي تم تعريفه الآن
        border: const Border(left: BorderSide(color: kGiftBorderColor, width: 5)), 
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.delivery_dining, color: kDeliverySummaryText, size: 20),
          const SizedBox(width: 10),
          Text(
            'رسوم التوصيل: ${fee.toStringAsFixed(2)} جنيه',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: kDeliverySummaryText,
            ),
          ),
        ],
      ),
    );
  }

  // محاكاة لـ .total-container
  Widget _buildTotalContainer(double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'الإجمالي الكلي',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          Text(
            '${total.toStringAsFixed(2)} جنيه',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // محاكاة لـ .action-buttons
  Widget _buildActionButtons(BuildContext context, CartProvider cartProvider) {
    final bool isCheckoutEnabled = !cartProvider.hasCheckoutErrors;

    return Column(
      children: [
        // زر إفراغ السلة
        ElevatedButton.icon(
          onPressed: () => cartProvider.clearCart(),
          icon: const Icon(Icons.delete, color: Colors.white),
          label: const Text('إفراغ السلة', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: kClearButtonColor,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
        ),
        const SizedBox(height: 15),
                                                        // زر إتمام الطلب
        ElevatedButton.icon(
          onPressed: isCheckoutEnabled ? () => cartProvider.proceedToCheckout(context) : null,
          icon: const Icon(Icons.check_circle, color: Colors.white),
          label: const Text('إتمام الطلب', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
        ),
      ],
    );
  }
}
