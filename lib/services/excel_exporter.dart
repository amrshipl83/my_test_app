// lib/services/excel_exporter.dart 
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_test_app/models/order_model.dart'; 
                                                     
class ExcelExporter {
  // ⭐️ دالة التصدير الرئيسية ⭐️
  static Future<String> exportOrders(List<OrderModel> orders, String userRole) async {
    // 1. طلب صلاحية التخزين
    if (Platform.isAndroid || Platform.isIOS) {
      if (await Permission.storage.request().isDenied) {
        throw Exception('صلاحية التخزين مرفوضة. لا يمكن حفظ الملف.');
      }
    }

    // 2. إنشاء كائن Excel
    final excel = Excel.createExcel();
    final Sheet sheet = excel['الطلبات'];

    // 3. تعريف الأعمدة
    final headerRow = [
      'رقم الطلب', 'الحالة', 'تاريخ الطلب', 'الإجمالي',
      'اسم الصنف', 'الكمية', 'سعر الوحدة', 'إجمالي الصنف', 'رابط الصورة'
    ];

    // تحويل رؤوس الأعمدة إلى TextCellValue
    final List<CellValue> headerCells = headerRow.map((h) => TextCellValue(h)).toList();
    sheet.insertRowIterables(headerCells, 0);

    // 4. تعبئة البيانات
    int rowIndex = 1;
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss', 'en_US');

    for (var order in orders) {
      // بما أن الطلب قد يحتوي على أكثر من صنف، نكرر بيانات الطلب الرئيسية لكل صنف
      for (var item in order.items) {
        
        // 4.1. حساب إجمالي الصنف وتصحيح مشكلة unitPrice ونوع البيانات
        // ⭐️ التصحيح 1: item.unitPrice الآن موجود بعد تعديل OrderItemModel ⭐️
        // ⭐️ التصحيح 2: تحويل نتيجة الضرب إلى double بشكل صريح لتجنب خطأ 'num' ⭐️
        final itemTotal = (item.quantity * item.unitPrice).toDouble(); 
                                                         
        // 4.2. صف البيانات
        final List<CellValue> rowData = [
          TextCellValue(order.id),
          TextCellValue(order.statusText),
          TextCellValue(formatter.format(order.orderDate)),
          DoubleCellValue(order.totalAmount), // الإجمالي الكلي يُكرر لكل صنف
          TextCellValue(item.name),
          IntCellValue(item.quantity),
          
          // ⭐️ التصحيح 3: استخدام DoubleCellValue مع item.unitPrice ⭐️
          DoubleCellValue(item.unitPrice),
          DoubleCellValue(itemTotal), 
          
          TextCellValue(item.imageUrl),
        ];
                                         
        // 4.3. إضافة الصف إلى الشيت
        sheet.insertRowIterables(rowData, rowIndex);
        rowIndex++;
      }
    }

    // 5. حفظ الملف
    final timeStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'Orders_Export_${timeStamp}.xlsx';
                                                                                                            
    // 5.1. تحديد مسار الحفظ 
    Directory? appDocumentsDirectory;                    
    if (Platform.isAndroid || Platform.isIOS) {
        appDocumentsDirectory = await getApplicationDocumentsDirectory();                                     
    } else {
        // لـ Windows/Linux/Web (إذا تم دعمها)
        appDocumentsDirectory = await getApplicationSupportDirectory();
    }

    if (appDocumentsDirectory == null) {
      throw Exception('تعذر العثور على مسار حفظ صالح.');
    }
                                                                                                         
    final filePath = '${appDocumentsDirectory.path}/$fileName';
                                                                                                    
    // 5.2. حفظ البيانات الفعلية للملف
    final fileBytes = excel.encode();

    if (fileBytes != null) {
      final file = File(filePath);
      await file.writeAsBytes(fileBytes, flush: true);
                                                          
      return filePath; // إرجاع مسار الملف المحفوظ
    } else {
      throw Exception('فشل في إنشاء محتوى ملف Excel.');
    }
  }
}
