// lib/controllers/offers_controller.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' show File, Directory, Platform;

// ❌ تم إزالة استيراد 'dart:html' القديم.
// ignore: avoid_web_libraries_in_flutter
// import 'dart:html' as html;

import 'package:my_test_app/models/offer_model.dart';

class OffersController with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collectionName = 'productOffers';

  // -------------------------------------------------------------------
  // 1) Stream Offers
  // -------------------------------------------------------------------
  Stream<List<ProductOfferModel>> streamOffers(String sellerId) {
    return _db
        .collection(_collectionName)
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('productName', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ProductOfferModel.fromFirestore(
                  // 🛠️ تم إعادة التحويل الآمن لتصحيح خطأ argument_type_not_assignable
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  // -------------------------------------------------------------------
  // 2) Delete
  // -------------------------------------------------------------------
  Future<bool> deleteOffer(String offerId) async {
    try {
      await _db.collection(_collectionName).doc(offerId).delete();
      return true;
    } catch (e) {
      debugPrint("Error deleting: $e");
      return false;
    }
  }

  // -------------------------------------------------------------------
  // 3) Export
  // -------------------------------------------------------------------
  Future<String> exportToExcel(BuildContext context, String sellerId) async {
    // 1. Storage Permission (Android only)
    if (!kIsWeb) {
      if (await Permission.storage.request().isDenied) {
        return 'خطأ: الرجاء منح إذن التخزين.';
      }
    }

    try {
      final QuerySnapshot snapshot = await _db
          .collection(_collectionName)
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('productName')
          .get();

      final List<ProductOfferModel> offers = snapshot.docs
          .map((doc) =>
              // 🛠️ تم إعادة التحويل الآمن لتصحيح خطأ argument_type_not_assignable
              ProductOfferModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (offers.isEmpty) {
        return 'لا توجد عروض للتصدير.';
      }

      // -------- Excel ----------
      final excel = Excel.createExcel();
      final Sheet sheet = excel['عروض البائع'];

      List<String> headers = [
        'ID',
        'اسم المنتج',
        'السعر',
        'الوحدة',
        'المخزون',
        'حد التحذير',
        'الفئة',
        'الحالة',
        'تاريخ الإنشاء',
      ];

      sheet.insertRowIterables(
        headers.map((h) => TextCellValue(h)).toList(),
        0,
      );

      for (int i = 0; i < offers.length; i++) {
        final o = offers[i];
        final first = o.units.isNotEmpty ? o.units.first : null;

        List<CellValue> row = [
          TextCellValue(o.id ?? ''),
          TextCellValue(o.productName),
          DoubleCellValue(first?.price ?? 0.0),
          TextCellValue(first?.unitName ?? 'قطعة'),
          IntCellValue(first?.availableStock ?? 0),
          IntCellValue(o.lowStockThreshold ?? 0),
          TextCellValue(o.sellerName),
          TextCellValue(o.status == 'active' ? 'مفعل' : 'معطل'),
          TextCellValue(
            o.createdAt != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(o.createdAt!.toDate())
                : 'N/A',
          ),
        ];

        sheet.insertRowIterables(row, i + 1);
      }

      final bytes = excel.encode();
      if (bytes == null) return 'خطأ في إنشاء الملف.';

      final fileName =
          'Offers_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      // ------------------------------------------------------------
      // WEB MODE
      // ------------------------------------------------------------
      if (kIsWeb) {
        return 'التصدير للويب غير مدعوم حاليًا بسبب الحاجة لتحديث مكتبات التنزيل.';
      }

      // ------------------------------------------------------------
      // ANDROID / IOS MODE
      // ------------------------------------------------------------
      Directory? directory;

      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        return 'خطأ: تعذر الحصول على مسار الحفظ.';
      }

      final fullPath = '${directory.path}/$fileName';
      final file = File(fullPath);

      await file.writeAsBytes(bytes, flush: true);

      return 'تم حفظ الملف في:\n$fullPath';
    } catch (e) {
      debugPrint("Export error: $e");
      return 'خطأ: فشل تصدير البيانات.';
    }
  }
}
