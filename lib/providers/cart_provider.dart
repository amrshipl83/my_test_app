// المسار: lib/providers/cart_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:my_test_app/services/marketplace_data_service.dart'; 

// =========================================================================
// 💡 هياكل البيانات المساعدة (Models)
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
  // 🌟 إضافة الحقلين هنا
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
    this.mainCategoryId, // 🌟
    this.subCategoryId,  // 🌟
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
    'mainCategoryId': mainCategoryId, // 🌟
    'subCategoryId': subCategoryId,   // 🌟
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
      mainCategoryId: json['mainCategoryId'] as String?, // 🌟
      subCategoryId: json['subCategoryId'] as String?,   // 🌟
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

  final Map<String, Map<String, dynamic>> _sellerRulesCache = {};
  final Map<String, List<Map<String, dynamic>>> _giftPromosCache = {};

  double _totalProductsAmount = 0.0;
  double _totalDeliveryFees = 0.0;
  bool _hasCheckoutErrors = false;

  Map<String, SellerOrderData> get sellersOrders => _sellersOrders;
  double get totalProductsAmount => _totalProductsAmount;
  double get totalDeliveryFees => _totalDeliveryFees;
  double get finalTotal => _totalProductsAmount + _totalDeliveryFees;
  bool get hasCheckoutErrors => _hasCheckoutErrors;
  int get cartTotalItems => _cartItems.where((item) => !item.isGift).length;
  int get itemCount => cartTotalItems; 
  int get cartTotalQuantity {
    return _cartItems.where((item) => !item.isGift).fold(0, (sum, item) => sum + item.quantity);
  }
  bool get isCartEmpty => _cartItems.where((item) => !item.isGift).isEmpty;

  Future<bool> get hasPendingCheckout async {
    final prefs = await SharedPreferences.getInstance();
    final checkoutJson = prefs.getString('checkoutOrders');
    if (checkoutJson != null && checkoutJson.isNotEmpty) {
      try {
        return json.decode(checkoutJson).isNotEmpty;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

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
          final rules = { 'minTotal': finalMinTotal, 'deliveryFee': finalDeliveryFee };
          _sellerRulesCache[sellerId] = rules;
          return rules;
        }
      }
    } catch (e) {}
    if (buyerRole == 'consumer' && finalMinTotal == 0.0 && finalDeliveryFee == 0.0) {
      try {
        final docSnap = await _db.collection('deliverySupermarkets').doc(sellerId).get();
        if (docSnap.exists) {
          final data = docSnap.data()!;
          finalMinTotal = (data['minimumOrderValue'] as num?)?.toDouble() ?? 0.0;
          finalDeliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {}
    }
    final rules = { 'minTotal': finalMinTotal, 'deliveryFee': finalDeliveryFee, 'buyerRole': buyerRole };
    _sellerRulesCache[sellerId] = rules;
    return rules;
  }

  Future<List<Map<String, dynamic>>> _getGiftPromosBySellerId(String sellerId) async {
    if (_giftPromosCache.containsKey(sellerId)) return _giftPromosCache[sellerId]!;
    try {
      final querySnapshot = await _db.collection('giftPromos').where('sellerId', isEqualTo: sellerId).where('status', isEqualTo: 'active').get();
      final promos = querySnapshot.docs.map((doc) => doc.data()).toList();
      _giftPromosCache[sellerId] = promos;
      return promos;
    } catch (e) { return []; }
  }

  List<CartItem> _calculateGifts(SellerOrderData sellerData, List<Map<String, dynamic>> promos) {
    final giftedItems = <CartItem>[];
    for (var promo in promos) {
      final trigger = promo['trigger'] as Map<String, dynamic>?;
      if (trigger == null) continue;
      int giftedQuantity = 0;
      if (trigger['type'] == "min_order") {
        final requiredValue = (trigger['value'] as num? ?? 0.0).toDouble();
        if (sellerData.total >= requiredValue) giftedQuantity = promo['giftQuantityPerBase'] as int? ?? 1;
      } else if (trigger['type'] == "specific_item") {
        final triggerOfferId = trigger['offerId'] as String?;
        final requiredQtyBase = trigger['triggerQuantityBase'] as int? ?? 1;
        final giftPerBase = promo['giftQuantityPerBase'] as int? ?? 1;
        final triggerUnitName = trigger['unitName'] as String?;
        final itemMatch = sellerData.items.firstWhere(
            (item) => item.offerId == triggerOfferId && item.unit == triggerUnitName,
            orElse: () => CartItem(offerId: '', productId: '', sellerId: '', sellerName: '', name: '', price: 0, unit: '', unitIndex: -1, quantity: 0, imageUrl: '')
        );
        if (itemMatch.offerId.isNotEmpty) {
          final timesTriggered = (itemMatch.quantity / requiredQtyBase).floor();
          giftedQuantity = min(timesTriggered * giftPerBase, promo['maxQuantity'] as int? ?? 9999);
        }
      }
      if (giftedQuantity > 0) {
        giftedItems.add(CartItem(
          isGift: true, name: promo['giftProductName'] as String? ?? 'هدية', quantity: giftedQuantity,
          unit: promo['giftUnitName'] as String? ?? 'وحدة', price: 0.00, offerId: promo['giftOfferId'] as String? ?? 'N/A',
          productId: promo['giftProductId'] as String? ?? 'N/A', sellerId: sellerData.sellerId, sellerName: sellerData.sellerName,
          unitIndex: -1, imageUrl: promo['giftProductImage'] as String? ?? '',
        ));
      }
    }
    return giftedItems;
  }

  Future<Map<String, dynamic>> _getProductOfferDetails(String offerId, int unitIndex) async {
    int productMinQty = 1; int productMaxQty = 9999; int actualAvailableStock = 9999; double currentPrice = 0.0;
    try {
      final offerDoc = await _db.collection('productOffers').doc(offerId).get();
      if (offerDoc.exists) {
        final data = offerDoc.data()!;
        productMinQty = (data['minOrder'] as num?)?.toInt() ?? 1;
        productMaxQty = (data['maxOrder'] as num?)?.toInt() ?? 9999;
        if (unitIndex != -1 && data['units'] is List && unitIndex < (data['units'] as List).length) {
          final unitData = data['units'][unitIndex];
          actualAvailableStock = (unitData['availableStock'] as num?)?.toInt() ?? 0;
          currentPrice = (unitData['price'] as num?)?.toDouble() ?? 0.0;
        }
      } else {
        final marketOfferDoc = await _db.collection('marketOffer').doc(offerId).get();
        if (marketOfferDoc.exists) {
          final data = marketOfferDoc.data()!;
          final units = data['units'] as List<dynamic>?;
          if (units != null && unitIndex >= 0 && unitIndex < units.length) {
            currentPrice = (units[unitIndex]['price'] as num?)?.toDouble() ?? 0.0;
          }
        } else { actualAvailableStock = 0; }
      }
    } catch (error) { actualAvailableStock = 0; }
    return { 'minQty': productMinQty, 'maxQty': productMaxQty, 'stock': actualAvailableStock, 'currentPrice': currentPrice };
  }

  Future<void> _saveCartToLocal(Map<String, SellerOrderData> currentOrders) async {
    final List<CartItem> itemsToSave = [];
    itemsToSave.addAll(_cartItems.where((item) => !item.isGift));
    if (currentOrders.isNotEmpty) {
      for(var order in currentOrders.values) { itemsToSave.addAll(order.giftedItems); }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cartItems', jsonEncode(itemsToSave.map((e) => e.toJson()).toList()));
  }

  Future<void> loadCartAndRecalculate(String userRole) async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString('cartItems');
    if (cartJson != null) {
      _cartItems = (jsonDecode(cartJson) as List).map((e) => CartItem.fromJson(e)).toList();
    } else { _cartItems = []; }

    if (_cartItems.isEmpty) {
      _sellersOrders = {}; _totalProductsAmount = 0.0; _totalDeliveryFees = 0.0; _hasCheckoutErrors = false;
      notifyListeners(); return;
    }

    final tempSellersOrders = <String, SellerOrderData>{};
    for (var item in _cartItems.where((item) => !item.isGift)) {
      tempSellersOrders.putIfAbsent(item.sellerId, () => SellerOrderData(sellerId: item.sellerId, sellerName: item.sellerName, items: [])).items.add(item);
    }

    _totalProductsAmount = 0.0; _totalDeliveryFees = 0.0; _hasCheckoutErrors = false;
    for (var sellerId in tempSellersOrders.keys) {
      final sellerData = tempSellersOrders[sellerId]!;
      final rules = await _getSellerBusinessRules(sellerId, userRole);
      sellerData.minOrderTotal = (rules['minTotal'] as num? ?? 0.0).toDouble();
      sellerData.deliveryFee = (rules['deliveryFee'] as num? ?? 0.0).toDouble();
      sellerData.total = 0.0; sellerData.hasProductErrors = false;

      for (var item in sellerData.items) {
        final details = await _getProductOfferDetails(item.offerId, item.unitIndex);
        if (details['currentPrice'] > 0.0) item.price = details['currentPrice']; else { sellerData.hasProductErrors = true; _hasCheckoutErrors = true; }
        sellerData.total += (item.price * item.quantity);
        final finalMax = min((details['stock'] as int), (details['maxQty'] as int));
        if (item.quantity > finalMax || item.quantity < (details['minQty'] as int)) { sellerData.hasProductErrors = true; _hasCheckoutErrors = true; }
      }

      if (sellerData.minOrderTotal > 0 && sellerData.total < sellerData.minOrderTotal) {
        sellerData.isMinOrderMet = false; sellerData.deliveryFee = 0.0;
        sellerData.minOrderAlert = 'ينقصك ${(sellerData.minOrderTotal - sellerData.total).toStringAsFixed(2)} جنيه.';
      } else {
        sellerData.isMinOrderMet = true; _totalDeliveryFees += sellerData.deliveryFee;
        sellerData.giftedItems = _calculateGifts(sellerData, await _getGiftPromosBySellerId(sellerId));
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
    // 🌟 الوسائط الجديدة هنا
    String? mainCategoryId, String? subCategoryId,
  }) async {
    String verifiedSellerName = sellerName;
    if (userRole == 'consumer') {
      verifiedSellerName = await _dataService.fetchSupermarketNameById(sellerId);
    }
    
    final int finalMax = min(availableStock, maxOrderQuantity);
    if (quantityToAdd < minOrderQuantity) throw Exception('أقل من الحد الأدنى');

    final index = _cartItems.indexWhere((item) => item.offerId == offerId && item.unitIndex == unitIndex);
    if (index != -1) {
      if ((_cartItems[index].quantity + quantityToAdd) > finalMax) throw Exception('تجاوز الحد');
      _cartItems[index].quantity += quantityToAdd;
    } else {
      _cartItems.add(CartItem(
        offerId: offerId, productId: productId, sellerId: sellerId, sellerName: verifiedSellerName,
        name: name, price: price, unit: unit, unitIndex: unitIndex, quantity: quantityToAdd,
        imageUrl: imageUrl, 
        mainCategoryId: mainCategoryId, // 🌟
        subCategoryId: subCategoryId,   // 🌟
      ));
    }
    await loadCartAndRecalculate(userRole);
  }

  Future<void> changeQty(CartItem item, int delta, String userRole) async {
    final idx = _cartItems.indexWhere((i) => i.offerId == item.offerId && !i.isGift);
    if (idx == -1) return;
    if ((_cartItems[idx].quantity + delta) <= 0) { await removeItem(_cartItems[idx], userRole); return; }
    _cartItems[idx].quantity += delta;
    await loadCartAndRecalculate(userRole);
  }

  Future<void> removeItem(CartItem itemToRemove, String userRole) async {
    _cartItems.removeWhere((i) => i.offerId == itemToRemove.offerId && !i.isGift);
    await loadCartAndRecalculate(userRole);
  }

  Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cartItems');
    _cartItems = []; _sellersOrders = {}; _totalProductsAmount = 0.0; _totalDeliveryFees = 0.0; _hasCheckoutErrors = false;
    notifyListeners();
  }

  Future<void> proceedToCheckout(BuildContext context, String userRole) async {
    await loadCartAndRecalculate(userRole);
    if (_hasCheckoutErrors) return;
    final ordersToProceed = <CartItem>[];
    for (final sellerData in _sellersOrders.values) {
      if (sellerData.isMinOrderMet) {
        if (sellerData.deliveryFee > 0) {
          ordersToProceed.add(CartItem(offerId: 'DELIVERY_${sellerData.sellerId}', productId: 'FEE', sellerId: sellerData.sellerId, sellerName: sellerData.sellerName, name: "رسوم التوصيل", price: sellerData.deliveryFee, unit: 'شحنة', unitIndex: -1, quantity: 1, imageUrl: ''));
        }
        ordersToProceed.addAll(sellerData.items);
        ordersToProceed.addAll(sellerData.giftedItems);
      }
    }
    if (ordersToProceed.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('checkoutOrders', jsonEncode(ordersToProceed.map((e) => e.toJson()).toList()));
      Navigator.of(context).pushNamed('/checkout');
    }
  }

  Future<void> cancelPendingCheckout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('checkoutOrders');
    notifyListeners();
  }
}
