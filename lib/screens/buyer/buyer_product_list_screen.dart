// المسار: lib/screens/buyer/buyer_product_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // 🚀 ضروري لاستخدام الـ Provider
import 'package:my_test_app/providers/cart_provider.dart'; // 🚀 استيراد البروفايدر

import 'package:my_test_app/widgets/buyer_product_header.dart';
import 'package:my_test_app/widgets/product_list_grid.dart';
import 'package:my_test_app/widgets/category_bottom_nav_bar.dart'; 
import 'package:my_test_app/widgets/manufacturers_banner.dart';

class BuyerProductListScreen extends StatefulWidget {
  final String mainCategoryId;
  final String subCategoryId;
  final String? manufacturerId;

  const BuyerProductListScreen({
    super.key,
    required this.mainCategoryId,
    required this.subCategoryId,
    this.manufacturerId,
  });

  @override
  State<BuyerProductListScreen> createState() => _BuyerProductListScreenState();
}

class _BuyerProductListScreenState extends State<BuyerProductListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _pageTitle = 'المنتجات...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubCategoryDetails();
    });
  }

  Future<void> _loadSubCategoryDetails() async {
    try {
      final docSnapshot = await _db.collection('subCategory').doc(widget.subCategoryId).get();
      if (docSnapshot.exists && mounted) {
        setState(() {
          _pageTitle = docSnapshot.data()?['name'] ?? 'قسم فرعي غير معروف';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _pageTitle = 'القسم غير موجود';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pageTitle = 'خطأ في التحميل';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: BuyerProductHeader(
        title: _pageTitle,
        isLoading: _isLoading,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManufacturersBanner(
            onManufacturerSelected: (id) {
              if (id == 'ALL') {
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              } else if (id != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BuyerProductListScreen(
                      mainCategoryId: widget.mainCategoryId,
                      subCategoryId: widget.subCategoryId,
                      manufacturerId: id,
                    ),
                  ),
                );
              }
            },
          ),
          Divider(height: 1.0, color: Colors.grey[300]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12.0, left: 10.0, right: 10.0, bottom: 0.0),
              child: ProductListGrid(
                subCategoryId: widget.subCategoryId,
                pageTitle: _pageTitle,
                manufacturerId: widget.manufacturerId,
              ),
            ),
          ),
        ],
      ),

      // 🎯 التعديل الجديد: إضافة أيقونة السلة العائمة مع العداد
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          // استخدام نفس الدالة التي كانت في الهيدر
          final cartCount = cartProvider.cartTotalItems; 

          return Stack(
            alignment: Alignment.topRight,
            children: [
              FloatingActionButton(
                onPressed: () => Navigator.of(context).pushNamed('/cart'),
                backgroundColor: const Color(0xFF4CAF50), // لون أخضر متناسق
                elevation: 6,
                child: const Icon(Icons.shopping_cart, color: Colors.white, size: 28),
              ),
              // العداد الأحمر (Badge)
              if (cartCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),

      bottomNavigationBar: const CategoryBottomNavBar(),
    );
  }
}
