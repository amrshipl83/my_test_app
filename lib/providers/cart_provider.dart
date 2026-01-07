import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:my_test_app/services/marketplace_data_service.dart';

// =========================================================================
// 💡 Models
// =========================================================================
class CartItem {
  final String offerId;
  final String productId;
  final String sellerId;
  final String sellerName;
  final String name;
  double price;
  final String unit;
  final int unitIndex;
  int quantity;
  final bool isGift;
  final String imageUrl;
  final String? mainCategoryId; 
  final String? subCategoryId;  

  CartItem({
    required this.offerId,
    required this.productId,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    required this.price,
    required this.unit,
    required this.unitIndex,
    this.quantity = 1,
    this.isGift = false,
    required this.imageUrl,
    this.mainCategoryId,
    this.subCategoryId,
  });

  Map<String, dynamic> toJson() => {
    'offerId': offerId,
    'productId': productId,
    'sellerId': sellerId,
    'sellerName': sellerName,
    'name': name,
    'price': price,
    'unit': unit,
    'unitIndex': unitIndex,
    'quantity': quantity,
    'isGift': isGift,
    'imageUrl': imageUrl,
    'mainCategoryId': mainCategoryId,
    'subCategoryId': subCategoryId,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      offerId: json['offerId'] as String,
      productId: json['productId'] as String? ?? json['offerId'] as String,
      sellerId: json['sellerId'] as String,
      sellerName: json['sellerName'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String,
      unitIndex: json['unitIndex'] as int,
      quantity: json['quantity'] as int? ?? 1,
      isGift: json['isGift'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String? ?? '',
      mainCategoryId: json['mainCategoryId'] as String?,
      subCategoryId: json['subCategoryId'] as String?,
    );
  }
}

class SellerOrderData {
  final String sellerId;
  final String sellerName;
  final List<CartItem> items;
  List<CartItem> giftedItems = [];
  double total = 0.0;
  double minOrderTotal = 0.0;
  double deliveryFee = 0.0;
  bool isMinOrderMet = true;
  bool hasProductErrors = false;
  String? minOrderAlert;

  SellerOrderData({
    required this.sellerId,
    required this.sellerName,
    required this.items,
  });
}

// =========================================================================
// 🛒 Cart Provider
// =========================================================================
class CartProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MarketplaceDataService _dataService = MarketplaceDataService();

  List<CartItem> _cartItems = [];
  Map<String, SellerOrderData> _sellersOrders = {};
  double _totalProductsAmount = 0.0;
  double _totalDeliveryFees = 0.0;
  bool _hasCheckoutErrors = false;

  // -----------------------------------------------------------------------
  // 🎯 Getters (تم تعديل المسميات لتطابق الـ UI المنهار في الـ Build)
  // -----------------------------------------------------------------------
  List<CartItem> get cartItems => _cartItems;
  Map<String, SellerOrderData> get sellersOrders => _sellersOrders;
  double get totalProductsAmount => _totalProductsAmount;
  double get totalDeliveryFees => _totalDeliveryFees;
  double get finalTotal => _totalProductsAmount + _totalDeliveryFees;
  bool get hasCheckoutErrors => _hasCheckoutErrors;
  
  // حل مشكلة Error: The getter 'isCartEmpty'
  bool get isCartEmpty => _cartItems.where((item) => !item.isGift).isEmpty;
  
  // حل مشكلة Error: The getter 'cartTotalItems'
  int get cartTotalItems => _cartItems.where((item) => !item.isGift).length;
  
  // حل مشكلة Error: The getter 'hasPendingCheckout'
  bool get hasPendingCheckout => _hasCheckoutErrors;

  // -----------------------------------------------------------------------
  // 🔄 النواة: حساب محتويات السلة
  // -----------------------------------------------------------------------
  Future<void> loadCartAndRecalculate(String userRole) async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString('cartItems');
    
    if (cartJson != null) {
      _cartItems = (jsonDecode(cartJson) as List).map((e) => CartItem.fromJson(e)).toList();
    } else {
      _cartItems = [];
    }

    if (_cartItems.isEmpty) {
      _sellersOrders = {}; _totalProductsAmount = 0.0; _totalDeliveryFees = 0.0; _hasCheckoutErrors = false;
      notifyListeners(); return;
    }

    final tempOrders = <String, SellerOrderData>{};
    for (var item in _cartItems.where((i) => !i.isGift)) {
      tempOrders.putIfAbsent(item.sellerId, () => SellerOrderData(sellerId: item.sellerId, sellerName: item.sellerName, items: [])).items.add(item);
    }

    _totalProductsAmount = 0.0; _totalDeliveryFees = 0.0; _hasCheckoutErrors = false;

    for (var sellerId in tempOrders.keys) {
      final data = tempOrders[sellerId]!;
      
      double minTotal = 0.0; double fee = 0.0;
      try {
        final doc = await _db.collection('sellers').doc(sellerId).get();
        if (doc.exists) {
          minTotal = (doc.data()?['minOrderTotal'] as num?)?.toDouble() ?? 0.0;
          fee = (doc.data()?['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        }
        if (userRole == 'consumer' && minTotal == 0.0) {
          final dDoc = await _db.collection('deliverySupermarkets').doc(sellerId).get();
          if (dDoc.exists) {
            minTotal = (dDoc.data()?['minimumOrderValue'] as num?)?.toDouble() ?? 0.0;
            fee = (dDoc.data()?['deliveryFee'] as num?)?.toDouble() ?? 0.0;
          }
        }
      } catch (e) {}

      data.minOrderTotal = minTotal;
      data.deliveryFee = fee;
      data.total = 0.0;

      for (var item in data.items) {
        try {
          final off = await _db.collection('productOffers').doc(item.offerId).get();
          if (off.exists) {
            final d = off.data()!;
            final int minQ = (d['minOrder'] as num?)?.toInt() ?? 1;
            final int maxQ = (d['maxOrder'] as num?)?.toInt() ?? 9999;
            int stock = 9999;
            if (item.unitIndex != -1 && d['units'] is List) {
              stock = (d['units'][item.unitIndex]['availableStock'] as num?)?.toInt() ?? 0;
            }
            
            int finalMaxLimit = min(stock, maxQ);
            if (item.quantity > finalMaxLimit || item.quantity < minQ) {
              data.hasProductErrors = true; 
              _hasCheckoutErrors = true;
            }
          }
        } catch (e) {}
        
        data.total += (item.price * item.quantity);
      }

      if (data.total < data.minOrderTotal) {
        data.isMinOrderMet = false; data.deliveryFee = 0.0;
      } else {
        data.isMinOrderMet = true; _totalDeliveryFees += data.deliveryFee;
      }
      _totalProductsAmount += data.total;
    }

    _sellersOrders = tempOrders;
    await _saveCartToLocal(_sellersOrders);
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // ➕ الإضافة (تم حل مشكلة المعاملات المفقودة مثل minOrderQuantity)
  // -----------------------------------------------------------------------
  Future<void> addItemToCart({
    required String offerId, required String productId, required String sellerId,
    required String sellerName, required String name, required double price,
    required String unit, required int unitIndex, int quantityToAdd = 1,
    required String imageUrl, required String userRole,
    String? mainCategoryId, String? subCategoryId,
    int? minOrderQuantity, // تم إضافته كمعامل اختياري لحل خطأ الـ Build
  }) async {
    final idx = _cartItems.indexWhere((i) => i.offerId == offerId && i.unitIndex == unitIndex);
    if (idx != -1) {
      _cartItems[idx].quantity += quantityToAdd;
    } else {
      _cartItems.add(CartItem(
        offerId: offerId, productId: productId, sellerId: sellerId, sellerName: sellerName,
        name: name, price: price, unit: unit, unitIndex: unitIndex, quantity: quantityToAdd,
        imageUrl: imageUrl, 
        mainCategoryId: mainCategoryId,
        subCategoryId: subCategoryId,
      ));
    }
    await loadCartAndRecalculate(userRole);
  }

  // -----------------------------------------------------------------------
  // 🛠 الدوال الأساسية
  // -----------------------------------------------------------------------
  Future<void> changeQty(CartItem item, int delta, String userRole) async {
    final idx = _cartItems.indexOf(item);
    if (idx != -1) {
      final newQty = _cartItems[idx].quantity + delta;
      if (newQty > 0) {
        _cartItems[idx].quantity = newQty;
        await loadCartAndRecalculate(userRole);
      } else {
        await removeItem(item, userRole);
      }
    }
  }

  Future<void> removeItem(CartItem item, String userRole) async {
    _cartItems.removeWhere((i) => i.offerId == item.offerId && i.unitIndex == item.unitIndex);
    await loadCartAndRecalculate(userRole);
  }

  Future<void> clearCart() async {
    _cartItems = []; _sellersOrders = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cartItems');
    notifyListeners();
  }

  Future<void> cancelPendingCheckout() async {
    _hasCheckoutErrors = false;
    notifyListeners();
  }

  void proceedToCheckout(BuildContext context, String role) {
    if (_hasCheckoutErrors) return;
    notifyListeners();
  }

  Future<void> _saveCartToLocal(Map<String, SellerOrderData> orders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cartItems', jsonEncode(_cartItems.map((e) => e.toJson()).toList()));
  }
}
