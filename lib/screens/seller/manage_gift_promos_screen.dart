// lib/screens/seller/manage_gift_promos_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter/foundation.dart'; // 🛠️ تم إضافة استيراد debugPrint

// 🔗 استيراد الـ Widget الجديد
import 'package:my_test_app/screens/seller/widgets/promo_card_widget.dart';

// ----------------------------------------------------------------------
// Firestore Constants
// ----------------------------------------------------------------------
// 🛠️ تم تصحيح الأسماء لـ lowerCamelCase
const String giftPromosCollection = "giftPromos";
const String productOffersCollection = "productOffers";

// ----------------------------------------------------------------------
// Data Model (Promo Class)
// ----------------------------------------------------------------------
class GiftPromo {
  final String id;
  final String promoName;
  final String giftOfferId;
  final String giftProductName;
  final int giftQuantityPerBase;
  final Map<String, dynamic> trigger;
  final Timestamp expiryDate;
  final num maxQuantity;
  final num usedQuantity;
  final num totalGiftValue;
  final num totalOrderValue;
  final String status;

  GiftPromo({
    required this.id,
    required this.promoName,
    required this.giftOfferId,
    required this.giftProductName,
    required this.giftQuantityPerBase,
    required this.trigger,
    required this.expiryDate,
    required this.maxQuantity,
    required this.usedQuantity,
    required this.totalGiftValue,
    required this.totalOrderValue,
    required this.status,
  });

  // 💡 دالة مساعدة لضمان قراءة الأرقام (num) بشكل آمن
  static num _safeNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  // 💡 دالة مساعدة لضمان قراءة الأعداد الصحيحة (int) بشكل آمن
  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  factory GiftPromo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final expiryTimestamp = data['expiryDate'] as Timestamp? ?? Timestamp.now();

    final max = _safeNum(data['maxQuantity']);
    final used = _safeNum(data['usedQuantity']);
    final giftValue = _safeNum(data['totalGiftValue']);
    final orderValue = _safeNum(data['totalOrderValue']);
    final giftQuantityPerBaseInt = _safeInt(data['giftQuantityPerBase']);

    // 🚨🚨🚨 إصلاح خطأ Map<dynamic, dynamic> 🚨🚨🚨
    final triggerData = data['trigger'];
    final Map<String, dynamic> safeTriggerData =
        triggerData is Map
            ? Map<String, dynamic>.from(triggerData)
            : {};

    return GiftPromo(
      id: doc.id,
      promoName: data['promoName'] ?? 'عرض غير مسمى',
      giftOfferId: data['giftOfferId'] ?? '',
      giftProductName: data['giftProductName'] ?? 'منتج هدية غير معروف',
      giftQuantityPerBase: giftQuantityPerBaseInt,
      trigger: safeTriggerData, // استخدام القيمة المصححة
      expiryDate: expiryTimestamp,
      maxQuantity: max,
      usedQuantity: used,
      totalGiftValue: giftValue,
      totalOrderValue: orderValue,
      status: data['status'] ?? 'inactive',
    );
  }
}

// ----------------------------------------------------------------------
// Main Screen Widget
// ----------------------------------------------------------------------

class ManageGiftPromosScreen extends StatefulWidget {
  final String currentSellerId;

  // 🛠️ تم استخدام super.key بدلاً من Key? key. تم إزالة Key? key,
  const ManageGiftPromosScreen({super.key, required this.currentSellerId});

  @override
  // 🛠️ لا يوجد داعي لتغيير الرؤية إذا كان الـ State هو private (_ManageGiftPromosScreenState)
  State<ManageGiftPromosScreen> createState() => _ManageGiftPromosScreenState();
}

class _ManageGiftPromosScreenState extends State<ManageGiftPromosScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<GiftPromo> _activePromos = [];

  @override
  void initState() {
    super.initState();
    _fetchSellerPromos();
  }

  // ----------------------------------------------------------------------
  // DATA FETCHING LOGIC - [DEBUG VERSION with try-catch]
  // ----------------------------------------------------------------------
  Future<void> _fetchSellerPromos() async {
    setState(() {
      _isLoading = true;
      _activePromos = [];
    });

    // 💡 خطوة التشخيص 1: طباعة المعرف
    debugPrint("DEBUG: Current Seller ID being used: ${widget.currentSellerId}");

    if (widget.currentSellerId.isEmpty) {
      debugPrint("DEBUG: Seller ID is empty. Cannot run query.");
      setState(() { _isLoading = false; });
      return;
    }

    try {
      // 1. الاستعلام يجلب جميع العروض للبائع (بدون شرط status أو التاريخ)
      final q = _firestore
          .collection(giftPromosCollection) // 🛠️ تم تصحيح الثابت
          .where("sellerId", isEqualTo: widget.currentSellerId);

      final querySnapshot = await q.get();

      // 💡 خطوة التشخيص 2: طباعة عدد الوثائق المسترجعة
      debugPrint("DEBUG: Number of documents fetched from Firestore: ${querySnapshot.docs.length}");

      List<GiftPromo> fetchedPromos = [];
      for (var doc in querySnapshot.docs) {
        try {
          final promo = GiftPromo.fromFirestore(doc); // 🚨 الآن يجب أن يعمل هذا السطر!

          // 💡 خطوة التشخيص 3: التحقق اليدوي من الحالة
          if (promo.status == 'active' && promo.expiryDate.toDate().isAfter(DateTime.now())) {
            fetchedPromos.add(promo);
            debugPrint("DEBUG: Added active promo: ${promo.promoName} - ID: ${promo.id}");
          } else {
            debugPrint("DEBUG: Skipping inactive or expired promo: ${promo.promoName}");
          }
        } catch (e) {
          // 🚨🚨 رسالة الخطأ التي نحتاجها في حال ظهر خطأ جديد
          debugPrint("🚨 CRITICAL MAPPING ERROR (Document ID: ${doc.id}): Failed to create GiftPromo object due to: $e");
        }
      }

      setState(() {
        _activePromos = fetchedPromos;
      });

    } catch (error) {
      debugPrint("🚨 CRITICAL ERROR fetching seller promos: $error");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ----------------------------------------------------------------------
  // ACTION HANDLERS (Disable Promo)
  // ----------------------------------------------------------------------

  Future<void> _disablePromo(String promoId, String promoName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعطيل العرض'),
        content: Text('هل أنت متأكد من تعطيل العرض "$promoName"؟ لن يظهر العرض للعملاء بعد التعطيل.'),
        actions: [
          TextButton(onPressed: () {
            if (!mounted) return; // 🛠️ إصلاح: Guard to prevent using context after disposal
            Navigator.of(context).pop(false);
          }, child: const Text('إلغاء')),
          TextButton(onPressed: () {
            if (!mounted) return; // 🛠️ إصلاح: Guard to prevent using context after disposal
            Navigator.of(context).pop(true);
          }, child: const Text('تعطيل')),
        ],
      ),
    );

    if (confirmed != true) return;

    final promoRef = _firestore.collection(giftPromosCollection).doc(promoId); // 🛠️ تم تصحيح الثابت

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.runTransaction((transaction) async {
        final promoDoc = await transaction.get(promoRef);

        if (!promoDoc.exists) {
          throw Exception("PROMO_NOT_FOUND");
        }

        final promoData = promoDoc.data()!;
        if (promoData['status'] != 'active') {
          throw Exception("ALREADY_INACTIVE");
        }

        transaction.update(promoRef, {
          'status': 'inactive',
          'disabledAt': Timestamp.now()
        });
      });

      if (!mounted) return; // 🛠️ إصلاح: Guard to prevent using context after async gap
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم تعطيل العرض "$promoName" بنجاح.')),
      );

      _fetchSellerPromos();

    } catch (error) {
      String message = "❌ فشل تعطيل العرض. حدث خطأ في قاعدة البيانات.";
      if (error.toString().contains("PROMO_NOT_FOUND")) {
        message = "❌ فشل التعطيل. العرض غير موجود.";
      } else if (error.toString().contains("ALREADY_INACTIVE")) {
        message = "⚠️ هذا العرض غير نشط بالفعل.";
      } else {
        debugPrint("Error disabling promo: $error"); // 🛠️ تم استبدال print
      }

      if (!mounted) return; // 🛠️ إصلاح: Guard to prevent using context after async gap
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openEditPage(String promoId) {
    if (!mounted) return; // 🛠️ إصلاح: Guard to prevent using context immediately
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('سيتم فتح شاشة تعديل العرض ID: $promoId.')),
    );
  }

  // ----------------------------------------------------------------------
  // BUILD METHOD
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xff28a745);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الهدايا الترويجية النشطة'),
        backgroundColor: primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activePromos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sentiment_dissatisfied, size: 80, color: Colors.grey),
                        const SizedBox(height: 15),
                        const Text(
                          'لا توجد عروض ترويجية نشطة حاليًا.',
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (!mounted) return; // 🛠️ إصلاح: Guard to prevent using context immediately
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('إنشاء عرض جديد', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(15.0),
                  itemCount: _activePromos.length,
                  itemBuilder: (context, index) {
                    final promo = _activePromos[index];

                    final formattedDate = intl.DateFormat('yyyy-MM-dd').format(promo.expiryDate.toDate());

                    String triggerText;
                    if (promo.trigger['type'] == 'min_order') {
                      triggerText = '${(promo.trigger['value'] ?? 0).toStringAsFixed(0)} ج.م فأكثر';
                    } else if (promo.trigger['type'] == 'specific_item') {
                      triggerText = 'شراء ${promo.trigger['triggerQuantityBase'] ?? 0} من ${promo.trigger['productName'] ?? 'منتج غير معروف'}';
                    } else {
                      triggerText = 'مشغل غير محدد';
                    }

                    final giftText = '${promo.giftQuantityPerBase} وحدة من ${promo.giftProductName}';

                    return PromoCardWidget(
                      promoId: promo.id,
                      promoName: promo.promoName,
                      giftText: giftText,
                      triggerText: triggerText,
                      expiryDate: formattedDate,
                      maxQuantity: promo.maxQuantity,
                      usedQuantity: promo.usedQuantity,
                      totalGiftValue: promo.totalGiftValue,
                      totalOrderValue: promo.totalOrderValue,
                      onDisable: () => _disablePromo(promo.id, promo.promoName),
                      onEdit: () => _openEditPage(promo.id),
                    );
                  },
                ),
    );
  }
}
