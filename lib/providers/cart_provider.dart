// lib/providers/cart_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:my_test_app/services/marketplace_data_service.dart';

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
  });

  Map<String, dynamic> toJson() => {
    'offerId': offerId, 'productId': productId, 'sellerId': sellerId,
    'sellerName': sellerName, 'name': name, 'price': price,
    'unit': unit, 'unitIndex': unitIndex, 'quantity': quantity,
    'isGift': isGift, 'imageUrl': imageUrl,
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

  SellerOrderData({required this.sellerId, required this.sellerName, required this.items});
}

class CartProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MarketplaceDataService _dataService = MarketplaceDataService();

  List<CartItem> _cartItems = [];
  Map<String, SellerOrderData> _sellersOrders = {};
  final Map<String, Map<String, dynamic>> _sellerRulesCache = {};
  final Map<String, List<Map<String, dynamic>>> _giftPromosCache = {};

  double _totalProductsAmount = 0.0;
  double _totalDeliveryFees = 0.0;
  bool _hasCheckoutErrors = false;
  bool _isProcessing = false;

  // الإضافة المطلوبة لحل خطأ الـ Build
  bool get hasPendingCheckout => _isProcessing; 

  // Getters
  Map<String, SellerOrderData> get sellersOrders => _sellersOrders;
  double get totalProductsAmount => _totalProductsAmount;
  double get totalDeliveryFees => _totalDeliveryFees;
  double get finalTotal => _totalProductsAmount + _totalDeliveryFees;
  bool get hasCheckoutErrors => _hasCheckoutErrors;
  int get cartTotalItems => _cartItems.where((item) => !item.isGift).length;
  int get itemCount => cartTotalItems;
  bool get isCartEmpty => _cartItems.where((item) => !item.isGift).isEmpty;
  bool get isProcessing => _isProcessing;

  Future<Map<String, dynamic>> _getSellerBusinessRules(String sellerId, String buyerRole) async {
    if (_sellerRulesCache.containsKey(sellerId)) return _sellerRulesCache[sellerId]!;
    double finalMinTotal = 0.0;
    double finalDeliveryFee = 0.0;

    try {
      final docSnap = await _db.collection('sellers').doc(sellerId).get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        finalMinTotal = (data['minOrderTotal'] as num?)?.toDouble() ?? 0.0;
        finalDeliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        if (buyerRole == 'buyer') {
          final rules = {'minTotal': finalMinTotal, 'deliveryFee': finalDeliveryFee};
          _sellerRulesCache[sellerId] = rules;
          return rules;
        }
      }
      if (buyerRole == 'consumer' && finalMinTotal == 0.0 && finalDeliveryFee == 0.0) {
        final consumerDoc = await _db.collection('deliverySupermarkets').doc(sellerId).get();
        if (consumerDoc.exists) {
          final data = consumerDoc.data()!;
          finalMinTotal = (data['minimumOrderValue'] as num?)?.toDouble() ?? 0.0;
          finalDeliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (_) {}

    final rules = {'minTotal': finalMinTotal, 'deliveryFee': finalDeliveryFee, 'buyerRole': buyerRole};
    _sellerRulesCache[sellerId] = rules;
    return rules;
  }

  Future<void> loadCartAndRecalculate(String userRole) async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString('cartItems');

    if (cartJson != null) {
      final List<dynamic> rawList = jsonDecode(cartJson);
      _cartItems = rawList.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      _cartItems = [];
    }

    if (_cartItems.isEmpty) {
      _sellersOrders = {};
      _totalProductsAmount = 0.0;
      _totalDeliveryFees = 0.0;
      notifyListeners();
      return;
    }

    final tempSellersOrders = <String, SellerOrderData>{};
    for (var item in _cartItems.where((item) => !item.isGift)) {
      if (!tempSellersOrders.containsKey(item.sellerId)) {
        tempSellersOrders[item.sellerId] = SellerOrderData(sellerId: item.sellerId, sellerName: item.sellerName, items: []);
      }
      tempSellersOrders[item.sellerId]!.items.add(item);
    }

    _totalProductsAmount = 0.0;
    _totalDeliveryFees = 0.0;
    _hasCheckoutErrors = false;

    for (var sellerId in tempSellersOrders.keys) {
      final sellerData = tempSellersOrders[sellerId]!;
      final rules = await _getSellerBusinessRules(sellerId, userRole);
      sellerData.minOrderTotal = (rules['minTotal'] as num? ?? 0.0).toDouble();
      sellerData.deliveryFee = (rules['deliveryFee'] as num? ?? 0.0).toDouble();

      sellerData.total = 0.0;
      for (var item in sellerData.items) {
        final details = await _getProductOfferDetails(item.offerId, item.unitIndex);
        if (details['currentPrice'] > 0) item.price = details['currentPrice'];
        sellerData.total += (item.price * item.quantity);
        final finalMax = min((details['stock'] as int), (details['maxQty'] as int));
        if (item.quantity > finalMax || item.quantity < (details['minQty'] as int)) {
          sellerData.hasProductErrors = true;
          _hasCheckoutErrors = true;
        }
      }

      if (sellerData.minOrderTotal > 0 && sellerData.total < sellerData.minOrderTotal) {
        sellerData.isMinOrderMet = false;
        sellerData.deliveryFee = 0.0;
        sellerData.minOrderAlert = 'ينقصك ${(sellerData.minOrderTotal - sellerData.total).toStringAsFixed(2)} جنيه لإتمام طلب ${sellerData.sellerName}.';
      } else {
        sellerData.isMinOrderMet = true;
        _totalDeliveryFees += sellerData.deliveryFee;
        final promos = await _getGiftPromosBySellerId(sellerId);
        sellerData.giftedItems = _calculateGifts(sellerData, promos);
      }
      _totalProductsAmount += sellerData.total;
    }
    _sellersOrders = tempSellersOrders;
    await _saveCartToLocal(tempSellersOrders);
    notifyListeners();
  }

  Future<void> addItemToCart({
    required String offerId, required String productId, required String sellerId,
    required String sellerName, required String name, required double price,
    required String unit, required int unitIndex, int quantityToAdd = 1,
    required String imageUrl, required String userRole,
    int minOrderQuantity = 1, int availableStock = 9999, int maxOrderQuantity = 9999,
  }) async {
    String verifiedSellerName = sellerName;
    if (userRole == 'consumer') {
      try {
        verifiedSellerName = await _dataService.fetchSupermarketNameById(sellerId);
      } catch (e) {
        throw 'خطأ في التحقق من اسم المتجر: $e';
      }
    }
    final int finalMax = min(availableStock, maxOrderQuantity);
    final index = _cartItems.indexWhere((item) => item.offerId == offerId && item.unitIndex == unitIndex);
    int existingQty = (index != -1) ? _cartItems[index].quantity : 0;

    if (existingQty + quantityToAdd > finalMax) throw 'تجاوزت الحد المسموح ($finalMax)';

    _cartItems.removeWhere((item) => item.isGift);
    if (index != -1) {
      _cartItems[index].quantity += quantityToAdd;
    } else {
      _cartItems.add(CartItem(
        offerId: offerId, productId: productId, sellerId: sellerId,
        sellerName: verifiedSellerName, name: name, price: price,
        unit: unit, unitIndex: unitIndex, quantity: quantityToAdd, imageUrl: imageUrl,
      ));
    }
    await loadCartAndRecalculate(userRole);
  }

  Future<void> proceedToCheckout(BuildContext context, String userRole) async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('جاري معالجة طلبك...'), duration: Duration(seconds: 1)),
    );

    await loadCartAndRecalculate(userRole);
    if (_hasCheckoutErrors) {
      _isProcessing = false;
      notifyListeners();
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('يرجى تصحيح أخطاء السلة أولاً')));
      return;
    }

    final ordersToProceed = <CartItem>[];
    final itemsToKeep = <CartItem>[];
    for (final sellerData in _sellersOrders.values) {
      if (sellerData.minOrderTotal > 0 && !sellerData.isMinOrderMet) {
        itemsToKeep.addAll(sellerData.items);
      } else {
        if (sellerData.deliveryFee > 0) {
          ordersToProceed.add(CartItem(
            offerId: 'DELIVERY_FEE_${sellerData.sellerId}', productId: 'DELIVERY_FEE',
            sellerId: sellerData.sellerId, sellerName: sellerData.sellerName,
            name: "رسوم التوصيل", price: sellerData.deliveryFee,
            unit: 'شحنة', unitIndex: -1, quantity: 1, imageUrl: '',
          ));
        }
        ordersToProceed.addAll(sellerData.items);
        ordersToProceed.addAll(sellerData.giftedItems);
      }
    }

    if (ordersToProceed.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cartItems', jsonEncode(itemsToKeep.map((e) => e.toJson()).toList()));
      await prefs.setString('checkoutOrders', jsonEncode(ordersToProceed.map((e) => e.toJson()).toList()));

      _isProcessing = false;
      notifyListeners();
      Navigator.of(context).pushNamed('/checkout');
    } else {
      _isProcessing = false;
      notifyListeners();
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('لا توجد طلبات مؤهلة لإتمامها')));
    }
  }

  Future<Map<String, dynamic>> _getProductOfferDetails(String offerId, int unitIndex) async {
    int minQ = 1, maxQ = 9999, stock = 9999; double price = 0.0;
    try {
      final offerDoc = await _db.collection('productOffers').doc(offerId).get();
      if (offerDoc.exists) {
        final data = offerDoc.data()!;
        minQ = (data['minOrder'] as num?)?.toInt() ?? 1;
        maxQ = (data['maxOrder'] as num?)?.toInt() ?? 9999;
        if (unitIndex != -1) {
          final unitList = data['units'] as List;
          final unit = unitList[unitIndex];
          stock = (unit['availableStock'] as num?)?.toInt() ?? 0;
          price = (unit['price'] as num?)?.toDouble() ?? 0.0;
        }
      } else {
        final marketDoc = await _db.collection('marketOffer').doc(offerId).get();
        if (marketDoc.exists) {
          final units = marketDoc.data()!['units'] as List;
          price = (units[unitIndex]['price'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (_) {}
    return {'minQty': minQ, 'maxQty': maxQ, 'stock': stock, 'currentPrice': price};
  }

  Future<List<Map<String, dynamic>>> _getGiftPromosBySellerId(String sellerId) async {
    if (_giftPromosCache.containsKey(sellerId)) return _giftPromosCache[sellerId]!;
    try {
      final snap = await _db.collection('giftPromos').where('sellerId', isEqualTo: sellerId).where('status', isEqualTo: 'active').get();
      final promos = snap.docs.map((doc) => doc.data()).toList();
      _giftPromosCache[sellerId] = promos;
      return promos;
    } catch (_) { return []; }
  }

  List<CartItem> _calculateGifts(SellerOrderData sellerData, List<Map<String, dynamic>> promos) {
    final gifts = <CartItem>[];
    for (var promo in promos) {
      int qty = 0;
      final trigger = promo['trigger'];
      if (trigger['type'] == "min_order") {
        if (sellerData.total >= trigger['value']) qty = promo['giftQuantityPerBase'];
      }
      if (qty > 0) {
        gifts.add(CartItem(
          isGift: true, name: promo['giftProductName'], quantity: qty, unit: promo['giftUnitName'],
          price: 0.0, offerId: promo['giftOfferId'], productId: promo['giftProductId'],
          sellerId: sellerData.sellerId, sellerName: sellerData.sellerName, unitIndex: -1, imageUrl: promo['giftProductImage'],
        ));
      }
    }
    return gifts;
  }

  Future<void> _saveCartToLocal(Map<String, SellerOrderData> orders) async {
    final items = _cartItems.where((i) => !i.isGift).toList();
    for (var o in orders.values) items.addAll(o.giftedItems);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cartItems', jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> changeQty(CartItem item, int delta, String role) async {
    final i = _cartItems.indexWhere((x) => x.offerId == item.offerId && !x.isGift);
    if (i != -1) {
      _cartItems[i].quantity += delta;
      if (_cartItems[i].quantity <= 0) {
        await removeItem(item, role);
      } else {
        await loadCartAndRecalculate(role);
      }
    }
  }

  Future<void> removeItem(CartItem item, String role) async {
    _cartItems.removeWhere((x) => x.offerId == item.offerId && !x.isGift);
    await loadCartAndRecalculate(role);
  }

  Future<void> clearCart() async {
    (await SharedPreferences.getInstance()).remove('cartItems');
    _cartItems = []; _sellersOrders = {}; notifyListeners();
  }

  Future<void> cancelPendingCheckout() async {
    (await SharedPreferences.getInstance()).remove('checkoutOrders');
    notifyListeners();
  }
}

