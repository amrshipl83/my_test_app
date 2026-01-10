// المسار: lib/widgets/product_list_grid.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/widgets/buyer_product_card.dart';
import 'package:my_test_app/providers/product_offers_provider.dart';
import 'package:sizer/sizer.dart';

class ProductListGrid extends StatelessWidget {
  final String subCategoryId;
  final String pageTitle;
  final String? manufacturerId;
  final Function(String productId, String? offerId)? onProductTap;

  const ProductListGrid({
    super.key,
    required this.subCategoryId,
    required this.pageTitle,
    this.manufacturerId,
    this.onProductTap,
  });

  Stream<QuerySnapshot> _getProductsStream() {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    Query productsQuery = db.collection('products')
      .where('subId', isEqualTo: subCategoryId)
      .where('status', isEqualTo: 'active')
      .orderBy('order', descending: false);
    
    if (manufacturerId != null) {
      productsQuery = productsQuery.where('manufacturerId', isEqualTo: manufacturerId);
    }
    return productsQuery.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (subCategoryId.isEmpty) {
      return const Center(child: Text('خطأ: لم يتم تحديد القسم الفرعي لعرض المنتجات.'));
    }
    
    final colorScheme = Theme.of(context).colorScheme;
    const double finalAspectRatio = 0.52; 

    return StreamBuilder<QuerySnapshot>(
      stream: _getProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colorScheme.primary) 
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ في تحميل المنتجات: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                manufacturerId != null
                    ? 'لا توجد منتجات لهذه الشركة المصنعة في قسم "$pageTitle".'
                    : 'لا توجد منتجات متاحة حاليًا في قسم "$pageTitle".',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Tajawal'),
              ),
            ),
          );
        }

        final products = snapshot.data!.docs;
        
        return GridView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: finalAspectRatio,
          ),
          itemBuilder: (context, index) {
            final productDoc = products[index];
            final productId = productDoc.id;
            final productData = productDoc.data() as Map<String, dynamic>;

            return ChangeNotifierProvider<ProductOffersProvider>(
              create: (_) => ProductOffersProvider(productId: productId),
              child: BuyerProductCard(
                productId: productId,
                productData: productData,
                onTap: (selectedProductId, selectedOfferId) {
                  // 🎯 [التعديل الجوهري]: تنفيذ الانتقال لصفحة التفاصيل فوراً
                  // المسار '/productDetails' معرف في ملف main.dart ويستقبل Map كأرجومنت
                  Navigator.of(context).pushNamed(
                    '/productDetails',
                    arguments: {
                      'productId': selectedProductId,
                      'offerId': selectedOfferId,
                    },
                  );

                  // استدعاء الـ callback الخارجي إذا كان موجوداً (اختياري)
                  onProductTap?.call(selectedProductId, selectedOfferId);
                },
              ),
            );
          },
        );
      },
    );
  }
}
