import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math'; // 💡 تم إضافة هذا السطر لإصلاح خطأ Math.min

// =========================================================================
// 💡 هياكل البيانات المساعدة (Models)
// =========================================================================
class CartItem {
  final String offerId;
  final String sellerId;
  final String sellerName;
  final String name;
  final double price;
  final String unit;
  final int unitIndex;
  int quantity; // قابلة للتغيير
  final bool isGift; // **تم التأكد من التعريف**

  CartItem({
    required this.offerId,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    required this.price,
    required this.unit,
    required this.unitIndex,
    this.quantity = 1,
    this.isGift = false, // **تم التأكد من التعريف**
  });

  Map<String, dynamic> toJson() => {
    'offerId': offerId,
    'sellerId': sellerId,
    'sellerName': sellerName,
    'name': name,
    'price': price,
    'unit': unit,
    'unitIndex': unitIndex,
    'quantity': quantity,
    'isGift': isGift, // **تم التأكد من الاستخدام**
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      offerId: json['offerId'] as String,
      sellerId: json['sellerId'] as String,
      sellerName: json['sellerName'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String,
      unitIndex: json['unitIndex'] as int,
      quantity: json['quantity'] as int,
      isGift: json['isGift'] as bool? ?? false,
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

  // الحالة الداخلية
  List<CartItem> _cartItems = [];
  Map<String, SellerOrderData> _sellersOrders = {};

  // Caching
  final Map<String, Map<String, dynamic>> _sellerRulesCache = {};
  final Map<String, List<Map<String, dynamic>>> _giftPromosCache = {};

  // الإجماليات
  double _totalProductsAmount = 0.0;
  double _totalDeliveryFees = 0.0;
  bool _hasCheckoutErrors = false;

  // ------------------------------------------
  // ✅ Getter Properties (للوصول من الـ UI)
  // ------------------------------------------
  Map<String, SellerOrderData> get sellersOrders => _sellersOrders;
  double get totalProductsAmount => _totalProductsAmount;
  double get totalDeliveryFees => _totalDeliveryFees;
  double get finalTotal => _totalProductsAmount + _totalDeliveryFees;
  bool get hasCheckoutErrors => _hasCheckoutErrors;

  // ✅ المُحضر المضاف (يحل خطأ 'cartTotalItems' not defined)
  int get cartTotalItems => _cartItems.where((item) => !item.isGift).length;

  int get cartTotalQuantity {
    // تم تغيير نوع الإرجاع إلى num (أو toInt) لتجنب خطأ الكومبايلر
    return _cartItems.where((item) => !item.isGift).fold(0, (sum, item) => sum + item.quantity);
  }
  bool get isCartEmpty => _cartItems.where((item) => !item.isGift).isEmpty;

  // ------------------------------------------
  // 1. دوال جلب القواعد (الاتصال بـ Firestore)
  // ------------------------------------------

  /// **تحديث: دالة جلب قواعد البائعين الحقيقية من Firestore**
  /// تطبق منطق البحث المزدوج حسب دور المستخدم (`buyer` / `consumer`).
  Future<Map<String, dynamic>> _getSellerBusinessRules(String sellerId, String buyerRole) async {
    if (_sellerRulesCache.containsKey(sellerId)) return _sellerRulesCache[sellerId]!;
    
    // ⚠️ ملاحظة: لا يوجد هنا delay، يتم الاعتماد على زمن استجابة Firestore الفعلي.
    
    double finalMinTotal = 0.0;
    double finalDeliveryFee = 0.0;

    // 1. البحث دائمًا في مجموعة 'sellers'
    try {
      final docSnap = await _db.collection('sellers').doc(sellerId).get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        finalMinTotal = (data['minOrderTotal'] as num?)?.toDouble() ?? 0.0;
        finalDeliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        
        // 🛑 القاعدة 1: إذا كان الدور 'buyer'، نعتمد على نتيجة 'sellers' فقط وننتهي.
        if (buyerRole == 'buyer') {
          final rules = { 'minTotal': finalMinTotal, 'deliveryFee': finalDeliveryFee };
          _sellerRulesCache[sellerId] = rules;
          return rules;
        }
      }
    } catch (e) {
      debugPrint('Firestore Error fetching from sellers: $e');
    }

    // 2. البحث الإضافي في 'deliverySupermarkets' (القاعدة 3: خاص بالمستهلكين)
    //    يتم هذا البحث إذا كان الدور 'consumer' ولم يتم إيجاد قواعد سابقة (finalMinTotal == 0.0)
    if (buyerRole == 'consumer' && finalMinTotal == 0.0 && finalDeliveryFee == 0.0) {
      try {
        // استخدام اسم المجموعة الصحيح بناءً على معلوماتك المحفوظة
        final docSnap = await _db.collection('deliverySupermarkets').doc(sellerId).get(); 
        if (docSnap.exists) {
          final data = docSnap.data()!;
          finalMinTotal = (data['minimumOrderValue'] as num?)?.toDouble() ?? 0.0;
          finalDeliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {
        debugPrint('Firestore Error fetching from deliverySupermarkets: $e');
      }
    }
    
    // 3. القاعدة 4: إرجاع النتائج (قد تكون 0/0) وتخزينها مؤقتاً
    final rules = {
      'minTotal': finalMinTotal, 
      'deliveryFee': finalDeliveryFee,
      'buyerRole': buyerRole, 
    };
    
    _sellerRulesCache[sellerId] = rules;
    return rules;
  }

  /// **تحديث: دالة جلب عروض الهدايا الحقيقية من Firestore**
  /// تستعلم عن مجموعة `giftPromos` بالاعتماد على `sellerId` و `status: active`.
  Future<List<Map<String, dynamic>>> _getGiftPromosBySellerId(String sellerId) async {
    if (_giftPromosCache.containsKey(sellerId)) return _giftPromosCache[sellerId]!;
    
    try {
      final querySnapshot = await _db
          .collection('giftPromos')
          .where('sellerId', isEqualTo: sellerId)
          .where('status', isEqualTo: 'active')
          .get();
      
      final promos = querySnapshot.docs.map((doc) => doc.data()).toList();
      _giftPromosCache[sellerId] = promos;
      return promos;

    } catch (e) {
      debugPrint('Firestore Error fetching giftPromos: $e');
      return [];
    }
  }

  // ------------------------------------------
  // دالة حساب الهدايا (تم تصحيح خطأ Math.min)
  // ------------------------------------------
  List<CartItem> _calculateGifts(SellerOrderData sellerData, List<Map<String, dynamic>> promos) {
    final giftedItems = <CartItem>[];
    for (var promo in promos) {
      final trigger = promo['trigger'] as Map<String, dynamic>?;
      if (trigger == null) continue;

      int giftedQuantity = 0;
      
      // منطق الهدايا حسب الحد الأدنى
      if (trigger['type'] == "min_order") {
        final requiredValue = (trigger['value'] as num? ?? 0.0).toDouble();
        if (sellerData.total >= requiredValue) {
          giftedQuantity = promo['giftQuantityPerBase'] as int? ?? 1;
        }
      } 
      
      // منطق الهدايا حسب منتج محدد
      else if (trigger['type'] == "specific_item") {
        final triggerOfferId = trigger['offerId'] as String?;
        final requiredQtyBase = trigger['triggerQuantityBase'] as int? ?? 1;
        final giftPerBase = promo['giftQuantityPerBase'] as int? ?? 1;
        final triggerUnitName = trigger['unitName'] as String?;

        final itemMatch = sellerData.items.firstWhere(
            (item) => item.offerId == triggerOfferId && item.unit == triggerUnitName,
            orElse: () => CartItem(offerId: '', sellerId: '', sellerName: '', name: '', price: 0, unit: '', unitIndex: -1, quantity: 0)
        );

        if (itemMatch.offerId.isNotEmpty) {
          final timesTriggered = (itemMatch.quantity / requiredQtyBase).floor();
          final totalGiftedQty = timesTriggered * giftPerBase;
          
          final maxAllowedGifts = promo['maxQuantity'] as int? ?? 9999;
          // 💡 تم تصحيح الاستدعاء من Math.min إلى min()
          giftedQuantity = min(totalGiftedQty, maxAllowedGifts); 
          // يجب تطبيق منطق reservedQuantity هنا أيضاً
        }
      }

      if (giftedQuantity > 0) {
        giftedItems.add(CartItem(
          isGift: true,
          name: promo['giftProductName'] as String? ?? 'هدية',
          quantity: giftedQuantity,
          unit: promo['giftUnitName'] as String? ?? 'وحدة',
          price: 0.00,
          offerId: promo['giftOfferId'] as String? ?? 'N/A',
          sellerId: sellerData.sellerId,
          sellerName: sellerData.sellerName,
          unitIndex: -1,
        ));
      }
    }
    return giftedItems;
  }

  /// **تحديث: دالة جلب تفاصيل العرض الحقيقية من Firestore**
  /// تستعلم عن مجموعتي `productOffers` أو `marketOffer` حسب الدور.
  Future<Map<String, dynamic>> _getProductOfferDetails(String offerId, int unitIndex) async {
    // ⚠️ لا نستخدم Cache هنا للتأكد من جلب أحدث قيمة للمخزون
    
    // القيم الافتراضية
    int productMinQty = 1;
    int productMaxQty = 9999;
    int actualAvailableStock = 9999;
    
    final collectionName = 'productOffers'; // المجموعة الأساسية لجميع الأدوار
    
    // إذا كنت تحتاج إلى التمييز بين الأدوار كما في HTML:
    // if (userRole == 'consumer') { ... } 
    // لكن لتبسيط المنطق في Flutter سنحاول جلب المخزون من productOffers

    try {
      final offerRef = _db.collection(collectionName).doc(offerId); 
      final offerDoc = await offerRef.get();
      
      if (offerDoc.exists) {
        final data = offerDoc.data()!;
        
        productMinQty = (data['minOrder'] as num?)?.toInt() ?? 1; 
        productMaxQty = (data['maxOrder'] as num?)?.toInt() ?? 9999;
        actualAvailableStock = 0; // القيمة الافتراضية للمخزون

        // منطق جلب المخزون بناءً على unitIndex
        if (unitIndex != -1 && data['units'] is List && unitIndex < (data['units'] as List).length) {
          actualAvailableStock = (data['units'][unitIndex]['availableStock'] as num?)?.toInt() ?? 0;
        } else if (data['availableQuantity'] != null) {
          actualAvailableStock = (data['availableQuantity'] as num?)?.toInt() ?? 0;
        }
      } else {
         // إذا لم يوجد في productOffers، نبحث في marketOffer (المنطق الاحتياطي للمستهلك)
         final marketOfferDoc = await _db.collection('marketOffer').doc(offerId).get();
         if (marketOfferDoc.exists) {
            final data = marketOfferDoc.data()!;
            productMinQty = (data['minOrder'] as num?)?.toInt() ?? 1; 
            productMaxQty = (data['maxOrder'] as num?)?.toInt() ?? 9999;
            actualAvailableStock = (data['availableQuantity'] as num?)?.toInt() ?? 0;
         } else {
             actualAvailableStock = 0; // المنتج غير متوفر
         }
      }

    } catch (error) {
      debugPrint('Firestore Error fetching product offer details: $error');
      actualAvailableStock = 0; 
    }

    return {
      'minQty': productMinQty,
      'maxQty': productMaxQty,
      'stock': actualAvailableStock
    };
  }

  // ------------------------------------------
  // 2. دوال الحفظ والتحميل (لم تتغير)
  // ------------------------------------------
  Future<void> _saveCartToLocal(Map<String, SellerOrderData> currentOrders) async {
    final List<CartItem> itemsToSave = [];
    itemsToSave.addAll(_cartItems.where((item) => !item.isGift)); // العناصر الأصلية

    // إضافة الهدايا فقط إذا تم الحفظ بعد LoadAndRecalculate (لتضمين الهدايا المستحقة)
    if (currentOrders.isNotEmpty) {
      for(var order in currentOrders.values) {
        itemsToSave.addAll(order.giftedItems);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final cartJson = jsonEncode(itemsToSave.map((e) => e.toJson()).toList());
    await prefs.setString('cartItems', cartJson);
  }

  // ------------------------------------------
  // 3. دالة المحرك الرئيسي (loadCartAndRecalculate) (لم تتغير)
  // ------------------------------------------
  Future<void> loadCartAndRecalculate(String userRole) async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString('cartItems');

    if (cartJson != null) {
      // 1. تنظيف السلة من الهدايا القديمة وإعادة جلب العناصر الأصلية فقط
      final List<dynamic> rawList = jsonDecode(cartJson);
      _cartItems = rawList.map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .where((item) => !item.isGift)
          .toList();
    } else {
      _cartItems = [];
    }

    if (_cartItems.isEmpty) {
      _sellersOrders = {};
      _totalProductsAmount = 0.0;
      _totalDeliveryFees = 0.0;
      _hasCheckoutErrors = false;
      notifyListeners();
      return;
    }

    // 2. تجميع الطلبات وحساب الإجمالي الفرعي
    final tempSellersOrders = <String, SellerOrderData>{};
    _totalProductsAmount = 0.0;

    for (var item in _cartItems) {
      final sellerId = item.sellerId;
      if (!tempSellersOrders.containsKey(sellerId)) {
        tempSellersOrders[sellerId] = SellerOrderData(
          sellerId: sellerId,
          sellerName: item.sellerName,
          items: [],
        );
      }
      tempSellersOrders[sellerId]!.total += (item.price * item.quantity);
      tempSellersOrders[sellerId]!.items.add(item);
      _totalProductsAmount += (item.price * item.quantity);
    }

    // 3. جلب القواعد والتحقق من الحد الأدنى والهدايا
    _totalDeliveryFees = 0.0;
    _hasCheckoutErrors = false;

    for (var sellerId in tempSellersOrders.keys) {
      final sellerData = tempSellersOrders[sellerId]!;

      // جلب القواعد (الآن تتصل بـ Firestore)
      final rules = await _getSellerBusinessRules(sellerId, userRole);
      sellerData.minOrderTotal = (rules['minTotal'] as num? ?? 0.0).toDouble();
      sellerData.deliveryFee = (rules['deliveryFee'] as num? ?? 0.0).toDouble();

      // التحقق من الحد الأدنى للطلب
      if (sellerData.minOrderTotal > 0 && sellerData.total < sellerData.minOrderTotal) {
        final remaining = (sellerData.minOrderTotal - sellerData.total).toStringAsFixed(2);
        sellerData.isMinOrderMet = false;
        sellerData.minOrderAlert = 'ينقصك $remaining جنيه لإتمام طلبك من ${sellerData.sellerName}.';
      } else {
        sellerData.isMinOrderMet = true;
        sellerData.minOrderAlert = 'تم تجاوز الحد الأدنى للطلب من ${sellerData.sellerName}.';
        _totalDeliveryFees += sellerData.deliveryFee;

        // حساب الهدايا المستحقة (الآن تتصل بـ Firestore)
        final promos = await _getGiftPromosBySellerId(sellerId);
        sellerData.giftedItems = _calculateGifts(sellerData, promos);
      }

      // 4. التحقق من قيود المخزون والحدود لكل منتج (الآن تتصل بـ Firestore)
      for (var item in sellerData.items) {
        final details = await _getProductOfferDetails(item.offerId, item.unitIndex);
        final finalMax = (details['stock'] as int) < (details['maxQty'] as int)
            ? (details['stock'] as int) : (details['maxQty'] as int);
        final finalMin = details['minQty'] as int;

        if (item.quantity > finalMax || item.quantity < finalMin) {
          sellerData.hasProductErrors = true;
          _hasCheckoutErrors = true;
        }
      }
    }

    _sellersOrders = tempSellersOrders;

    // 5. حفظ السلة النهائية (بما في ذلك الهدايا المستحقة)
    await _saveCartToLocal(tempSellersOrders);

    notifyListeners();
  }

  // ------------------------------------------
  // 4. دوال التحكم في السلة والتفاعل (لم تتغير)
  // ------------------------------------------
  // 💡 إضافة منتج جديد أو تحديث منتج موجود
  Future<void> addItemToCart(
    String offerId,
    String sellerId,
    String sellerName,
    String name,
    double price,
    String unit,
    int unitIndex,
    int quantityToAdd,
  ) async {
    _cartItems.removeWhere((item) => item.isGift); // تنظيف الهدايا القديمة

    final index = _cartItems.indexWhere(
      (item) => item.offerId == offerId && item.unitIndex == unitIndex,
    );

    if (index != -1) {
      _cartItems[index].quantity += quantityToAdd;
    } else {
      final newItem = CartItem(
        offerId: offerId,
        sellerId: sellerId,
        sellerName: sellerName,
        name: name,
        price: price,
        unit: unit,
        unitIndex: unitIndex,
        quantity: quantityToAdd,
        isGift: false,
      );
      _cartItems.add(newItem);
    }

    await _saveCartToLocal(_sellersOrders);
    await loadCartAndRecalculate('consumer');
  }

  // 💡 تغيير الكمية وإعادة الحساب
  Future<void> changeQty(CartItem item, int delta) async {
    final index = _cartItems.indexWhere((i) => i.offerId == item.offerId && !i.isGift);
    if (index == -1) return;

    final newQty = _cartItems[index].quantity + delta;

    if (newQty <= 0) {
      await removeItem(_cartItems[index]);
      return;
    }

    // التحقق من المخزون قبل التغيير
    final details = await _getProductOfferDetails(item.offerId, item.unitIndex);
    final finalMax = (details['stock'] as int) < (details['maxQty'] as int)
        ? (details['stock'] as int) : (details['maxQty'] as int);

    if (finalMax < 9999 && newQty > finalMax) {
      debugPrint('ALERT: الحد الأقصى المتاح للطلب هو $finalMax وحدة.');
      return;
    }

    _cartItems[index].quantity = newQty;
    await _saveCartToLocal(_sellersOrders);
    await loadCartAndRecalculate('consumer');
  }

  // 💡 حذف عنصر وإعادة الحساب
  Future<void> removeItem(CartItem itemToRemove) async {
    _cartItems.removeWhere((i) => i.offerId == itemToRemove.offerId && !i.isGift);

    await _saveCartToLocal(_sellersOrders);
    await loadCartAndRecalculate('consumer');
  }

  // 💡 إفراغ السلة
  Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cartItems');

    _cartItems = [];
    _sellersOrders = {};
    _totalProductsAmount = 0.0;
    _totalDeliveryFees = 0.0;
    _hasCheckoutErrors = false;

    notifyListeners();
  }

  // 💡 منطق إتمام الطلب (Checkout)
  Future<void> proceedToCheckout(BuildContext context) async {
    if (_hasCheckoutErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تصحيح أخطاء الكمية والمخزون قبل إتمام الطلب.')),
      );
      return;
    }

    final ordersToProceed = <CartItem>[];
    final itemsToKeep = <CartItem>[];

    bool allOrdersValidForCheckout = true;
    final ordersToAlert = <Map<String, dynamic>>[];

    for (final sellerData in _sellersOrders.values) {
      if (sellerData.minOrderTotal > 0 && !sellerData.isMinOrderMet) {
        allOrdersValidForCheckout = false;
        ordersToAlert.add({
          'sellerName': sellerData.sellerName,
          'currentTotal': sellerData.total,
          'minTotal': sellerData.minOrderTotal,
        });
        itemsToKeep.addAll(sellerData.items);
      } else {
        if (sellerData.deliveryFee > 0) {
          ordersToProceed.add(CartItem(
            offerId: 'DELIVERY_FEE_${sellerData.sellerId}',
            sellerId: sellerData.sellerId,
            sellerName: sellerData.sellerName,
            name: "رسوم التوصيل",
            price: sellerData.deliveryFee,
            unit: 'شحنة',
            unitIndex: -1,
            quantity: 1,
            isGift: false,
          ));
        }

        ordersToProceed.addAll(sellerData.items);
        ordersToProceed.addAll(sellerData.giftedItems);
      }
    }

    if (!allOrdersValidForCheckout) {
      String alertMessage = "تنبيه: سيتم إتمام الطلبات التي تحقق الحد الأدنى فقط.\nالطلبات غير المؤهلة:\n";
      for (var order in ordersToAlert) {
        alertMessage += "  - التاجر \"${order['sellerName']}\": الإجمالي ${order['currentTotal'].toStringAsFixed(2)} جنيه (الحد الأدنى: ${order['minTotal'].toStringAsFixed(2)} جنيه)\n";
      }

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تنبيه بخصوص الطلب'),
          content: Text(alertMessage),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('متابعة')),
          ],
        )
      );
    }

    if (ordersToProceed.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();

      final remainingCartJson = jsonEncode(itemsToKeep.map((e) => e.toJson()).toList());
      await prefs.setString('cartItems', remainingCartJson);

      final checkoutOrdersJson = jsonEncode(ordersToProceed.map((e) => e.toJson()).toList());
      await prefs.setString('checkoutOrders', checkoutOrdersJson);

      await loadCartAndRecalculate('consumer');
      // 💡 [ملاحظة]: قم بتغيير هذا للتوجيه الفعلي لصفحة الدفع
      // Navigator.of(context).pushNamed('/checkout');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تجهيز الطلبات المؤهلة للدفع!')),
      );
    } else if (!allOrdersValidForCheckout) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إتمام أي طلب. جميع الطلبات أقل من الحد الأدنى المطلوب.')),
      );
    }
  }
}
