// lib/screens/invoice_screen.dart                                                                        
import 'package:flutter/material.dart';              
import 'package:intl/intl.dart';                     
import 'package:printing/printing.dart';             
import 'package:pdf/pdf.dart';                       
// 💡 تحديث الاستيراد: يفضل استخدام pw.TableHelper (لحل مشكلة deprecated_member_use)
import 'package:pdf/widgets.dart' as pw;             
import 'dart:typed_data';                            
import 'dart:developer' as developer; // ⭐️ جديد: لاستخدامه في الـ logs ⭐️                                                                                     

import 'package:my_test_app/models/order_model.dart';
import 'package:my_test_app/models/seller_model.dart'; // ⭐️ جديد: نموذج بيانات البائع ⭐️                 
import 'package:my_test_app/data_sources/seller_data_source.dart'; // ⭐️ جديد: خدمة جلب البيانات ⭐️                                                            

// 1. تحويل الشاشة إلى StatefulWidget                
class InvoiceScreen extends StatefulWidget {           
  final OrderModel order;                              
  const InvoiceScreen({super.key, required this.order});                                                                                                         
  
  @override                                            
  State<InvoiceScreen> createState() => _InvoiceScreenState();                                            
}                                                                                                         

class _InvoiceScreenState extends State<InvoiceScreen> {                                                    
  // 2. تعريف متغيرات الحالة                           
  final SellerDataSource _sellerDataSource = SellerDataSource();                                                                                                 
                                                                                                          
  // قيمة أولية افتراضية لعرضها أثناء التحميل          
  SellerModel _sellerDetails = SellerModel.defaultPlaceholder();                                            
  bool _isLoadingSeller = true;                                                                             
                                                                                                          
  @override                                            
  void initState() {                                     
    super.initState();                                   
    _fetchSellerDetails();                             
  }                                                                                                         
                                                                                                          
  // 3. دالة جلب بيانات البائع                         
  Future<void> _fetchSellerDetails() async {             
    final sellerId = widget.order.sellerId;              
    developer.log('Attempting to fetch seller details for ID: $sellerId', name: 'InvoiceScreen');                                                                  
                                                                                                          
    if (sellerId.isEmpty) {
      // 🛠️ تصحيح curly_braces_in_flow_control_structures
      if (mounted) {
        setState(() {                                
          _sellerDetails = SellerModel(                          
            id: '',                                              
            name: 'معرّف البائع مفقود!',                          
            phone: '---',                                        
            address: '---',                                    
          );                                                   
          _isLoadingSeller = false;                        
        });                                                  
      }
      return;                                          
    }                                                                                                         
                                                                                                          
    try {                                                  
      final details = await _sellerDataSource.getSellerDetails(sellerId);                                       
      if (mounted) {                                          
        setState(() {                                          
          _sellerDetails = details;                            
          _isLoadingSeller = false;                          
        });                                                
      }                                                  
    } catch (e) {                                          
      developer.log('Error fetching seller details: $e', name: 'InvoiceScreen', error: e);                      
      // 🛠️ تصحيح curly_braces_in_flow_control_structures
      if (mounted) { 
        setState(() {                              
          _isLoadingSeller = false;                            
          // الاحتفاظ ببيانات افتراضية إذا فشل الجلب           
          _sellerDetails = SellerModel(                              
            id: sellerId,                                        
            name: 'فشل في جلب اسم المتجر',                       
            phone: '---',                                        
            address: 'يرجى التحقق من اتصال الإنترنت',                                                               
          );                                             
        });                                                
      }
    }                                                  
  }                                                                                                         
                                                                                                          
  // 1. بناء مستند PDF للفاتورة الورقية (A4)           
  Future<Uint8List> _buildA4Invoice(PdfPageFormat format) async {                                             
    final pdf = pw.Document();                                                                                
                                                                                                          
    // جلب الخطوط العربية (لضمان الدعم الكامل للغة العربية)                                                   
    final font = await PdfGoogleFonts.cairoRegular();    
    final boldFont = await PdfGoogleFonts.cairoBold();                                                                                                             
                                                                                                          
    // تصميم الرأس والبيانات الأساسية                    
    pdf.addPage(                                           
      pw.Page(                                               
        pageFormat: format,                                  
        build: (pw.Context context) {                          
          return pw.Directionality(                              
            textDirection: pw.TextDirection.rtl,                 
            child: pw.Column(                                      
              crossAxisAlignment: pw.CrossAxisAlignment.start,                                                          
              children: [                                            
                // ⭐️ رأس الفاتورة يستخدم بيانات البائع الحقيقية ⭐️                                                       
                _buildHeader(boldFont, _sellerDetails),                                                                   
                pw.SizedBox(height: 20),                                                                                                                                       
                // ⭐️ تفاصيل العميل والطلب ⭐️                        
                _buildOrderDetailsTable(font, boldFont),                                                                  
                pw.SizedBox(height: 30),                                                                                                                                       
                // ⭐️ جدول المنتجات ⭐️                               
                _buildItemsTable(font, boldFont),                    
                pw.SizedBox(height: 30),                                                                                                                                       
                // ⭐️ الملخص المالي ⭐️                               
                _buildSummaryTable(font, boldFont),                  
                pw.Spacer(),                                                                                                                                                   
                // ⭐️ تذييل الفاتورة ⭐️                              
                _buildFooter(font, _sellerDetails.name),                                                                
              ],                                                 
            ),                                                 
          );                                                 
        },                                                 
      ),                                                 
    );                                                   
    return pdf.save();                                 
  }                                                                                                                                                              
                                                                                                          
  // 2. دالة مساعدة لبناء رأس الفاتورة (تم إضافة SellerModel كوسيط)                                         
  pw.Widget _buildHeader(pw.Font boldFont, SellerModel sellerDetails) {                                       
    return pw.Container(                                   
      decoration: pw.BoxDecoration(                          
        border: pw.Border.all(color: PdfColors.grey),        
        borderRadius: pw.BorderRadius.circular(8),           
        color: PdfColor.fromInt(0xFFE0F7FA), // لون فاتح                                                        
      ),                                                   
      padding: const pw.EdgeInsets.all(12),                
      child: pw.Row(                                         
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,                                                     
        children: [                                            
          pw.Column(                                             
            crossAxisAlignment: pw.CrossAxisAlignment.start,                                                          
            children: [                                            
              pw.Text('الفاتورة الضريبية', style: pw.TextStyle(font: boldFont, fontSize: 18, color: PdfColors.blueGrey700)),                                                 
              pw.SizedBox(height: 5),                              
              pw.Text('رقم الفاتورة: ${widget.order.id}', style: pw.TextStyle(font: boldFont, fontSize: 10)),                                                                
              pw.Text('التاريخ: ${DateFormat('yyyy/MM/dd HH:mm').format(widget.order.orderDate)}', style: pw.TextStyle(font: boldFont, fontSize: 10)),                     
            ],                                                 
          ),                                                   
          pw.Column(                                             
            crossAxisAlignment: pw.CrossAxisAlignment.end,                                                            
            children: [                                            
              // ⭐️ استخدام بيانات البائع الحقيقية ⭐️              
              pw.Text(sellerDetails.name, style: pw.TextStyle(font: boldFont, fontSize: 16)),                           
              pw.Text('هاتف: ${sellerDetails.phone}', style: pw.TextStyle(font: boldFont, fontSize: 10)),               
              pw.Text('العنوان: ${sellerDetails.address}', style: pw.TextStyle(font: boldFont, fontSize: 10)),                                                             
            ],                                                 
          ),                                                 
        ],                                                 
      ),                                                 
    );                                                 
  }                                                                                                         
                                                                                                          
  // 3. دالة بناء جدول تفاصيل العميل والطلب            
  pw.Widget _buildOrderDetailsTable(pw.Font font, pw.Font boldFont) {                                         
    return pw.Container(                                   
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),                               
      // 🛠️ تصحيح deprecated_member_use: استخدام TableHelper
      child: pw.TableHelper.fromTextArray(                         
        headers: ['البيانات', 'القيمة'],                     
        cellAlignment: pw.Alignment.centerRight,             
        headerStyle: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.white),                          
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),                                   
        cellStyle: pw.TextStyle(font: font, fontSize: 10),                                                        
        columnWidths: {0: const pw.FixedColumnWidth(2.5), 1: const pw.FixedColumnWidth(1)},                       
        data: <List<String>>[                                  
          ['اسم العميل', widget.order.buyerDetails.name],                                                           
          ['هاتف العميل', widget.order.buyerDetails.phone],                                                         
          ['عنوان التوصيل', widget.order.buyerDetails.address],                                                     
          ['حالة الطلب', widget.order.statusText],           
        ],                                                 
      ),                                                 
    );                                                 
  }                                                                                                         
                                                                                                          
  // 4. دالة بناء جدول المنتجات                        
  pw.Widget _buildItemsTable(pw.Font font, pw.Font boldFont) {                                                
    const headers = ['الإجمالي', 'سعر الوحدة', 'الكمية', 'اسم الصنف'];                                        
    final data = widget.order.items.map((item) {           
      // item.unitPrice تم تصحيحه في OrderItemModel        
      final total = item.quantity * item.unitPrice;        
      return [                                               
        '${total.toStringAsFixed(2)} ج',                     
        '${item.unitPrice.toStringAsFixed(2)} ج',            
        item.quantity.toString(),                            
        item.name,                                         
      ];                                                 
    }).toList();                                                                                              
                                                                                                          
    return pw.TableHelper.fromTextArray( // 🛠️ تصحيح deprecated_member_use: استخدام TableHelper
      headers: headers.reversed.toList(), // لعرض الرؤوس بالترتيب الصحيح                                        
      data: data,                                          
      border: null,                                        
      headerStyle: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.white),                          
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),                                      
      cellStyle: pw.TextStyle(font: font, fontSize: 10),                                                        
      cellAlignment: pw.Alignment.centerRight,             
      // تحديد محاذاة كل عمود لضمان أن تكون الأرقام متوافقة مع الاتجاه                                          
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},                         
    );                                                 
  }                                                                                                         
                                                                                                          
  // 5. دالة بناء جدول الملخص المالي                   
  pw.Widget _buildSummaryTable(pw.Font font, pw.Font boldFont) {                                              
    return pw.Container(                                   
      alignment: pw.Alignment.centerLeft,                  
      child: pw.Column(                                      
        children: [                                            
          _buildSummaryRow(boldFont, font, 'الإجمالي قبل الخصم:', widget.order.grossTotal.toStringAsFixed(2), PdfColors.black),                                          
          _buildSummaryRow(boldFont, font, 'خصم الكاش باك:', '-${widget.order.cashbackApplied.toStringAsFixed(2)}', PdfColors.red),                                      
          _buildSummaryRow(boldFont, font, 'المبلغ الصافي المطلوب:', widget.order.totalAmount.toStringAsFixed(2), PdfColors.blueGrey800, isTotal: true),               
        ],                                                 
      ),                                                 
    );                                                 
  }                                                                                                         
                                                                                                          
  // 6. دالة مساعدة لصف الملخص                         
  pw.Widget _buildSummaryRow(pw.Font boldFont, pw.Font font, String label, String value, PdfColor color, {bool isTotal = false}) {                                 
    return pw.Padding(                                     
      padding: const pw.EdgeInsets.symmetric(vertical: 3),                                                      
      child: pw.Row(                                         
        mainAxisAlignment: pw.MainAxisAlignment.end,         
        children: [                                            
          pw.Container(                                          
            width: 150, // عرض ثابت للملخص                       
            child: pw.Row(                                         
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,                                                     
              children: [                                            
                pw.Text('$value ج', style: pw.TextStyle(font: isTotal ? boldFont : font, fontSize: isTotal ? 16 : 12, color: color)),                                          
                pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 12)),                                      
              ],                                                 
            ),                                                 
          ),                                                 
        ],                                                 
      ),                                                 
    );                                                 
  }                                                                                                         
                                                                                                          
  // 7. دالة بناء تذييل الفاتورة                       
  pw.Widget _buildFooter(pw.Font font, String sellerName) {                                                   
    return pw.Center(                                      
      child: pw.Text(                                        
        'نشكركم لاختياركم $sellerName. نتطلع لخدمتكم مجدداً.',                                                     
        style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey),                                   
      ),                                                 
    );                                                 
  }                                                                                                         
                                                                                                          
  @override                                            
  Widget build(BuildContext context) {                   
    return Scaffold(                                       
      appBar: AppBar(                                        
        title: const Text('معاينة وطباعة الفاتورة'),         
        backgroundColor: Theme.of(context).primaryColor,                                                        
      ),                                                   
      // ⭐️ استخدام PdfPreview وربطه بحالة التحميل ⭐️      
      body: _isLoadingSeller                                   
        ? const Center(child: CircularProgressIndicator()) // عرض مؤشر التحميل أثناء جلب بيانات البائع            
        : PdfPreview(                                            
            build: (format) => _buildA4Invoice(format), // بناء الفاتورة بحجم A4                                      
            // يمكن تخصيص الإجراءات (Actions) هنا              
          ),                                           
    );                                                 
  }                                                  
}
