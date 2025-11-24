// lib/screens/invoices_screen.dart                                                                       
import 'package:flutter/material.dart';              
import 'package:cloud_firestore/cloud_firestore.dart';                                                    
import 'package:firebase_auth/firebase_auth.dart';   
import 'package:intl/intl.dart';                                                                          

class InvoiceScreen extends StatefulWidget {           
  // يمكن تمرير الـ sellerId مباشرة إذا كان معروفًا مسبقًا                                                    
  final String? sellerId;                                                                                   
  
  const InvoiceScreen({super.key, this.sellerId});                                                          
  
  @override                                            
  State<InvoiceScreen> createState() => _InvoiceScreenState();                                            
}                                                                                                         

class _InvoiceScreenState extends State<InvoiceScreen> {                                                    
  late Future<QuerySnapshot> _invoicesFuture;                                                               
  
  @override                                            
  void initState() {                                     
    super.initState();                                   
    // بدء جلب الفواتير عند إنشاء الحالة                 
    _invoicesFuture = _fetchInvoices();                
  }                                                                                                         
                                                                                                          
  // ----------------------------------------------------------------------                                 
  // منطق جلب البيانات من Firestore (مطابق لمنطق الـ HTML)                                                  
  // ----------------------------------------------------------------------                                 
  Future<QuerySnapshot> _fetchInvoices() async {         
    final sellerId = widget.sellerId ?? FirebaseAuth.instance.currentUser?.uid;                                                                                    
    
    if (sellerId == null) {                                
      // إطلاق خطأ يمكن معالجته في FutureBuilder           
      throw Exception('الرجاء تسجيل الدخول أولاً للوصول إلى هذه الصفحة.');                                     
    }                                                                                                         
    
    // 1. إنشاء استعلام لجلب فواتير التاجر وفرزها حسب تاريخ الإنشاء (الأحدث أولاً)                             
    final invoicesQuery = FirebaseFirestore.instance         
      .collection('invoices')                              
      .where('sellerId', isEqualTo: sellerId)              
      .orderBy('creationDate', descending: true); // الأحدث أولاً                                                                                                 
                                                                                                          
    return invoicesQuery.get();                        
  }                                                                                                         
                                                                                                          
  // ----------------------------------------------------------------------                                 
  // دالة تنسيق العملة                                 
  // ----------------------------------------------------------------------                                 
  String _formatCurrency(dynamic amount) {               
    if (amount == null) return '0.00 ج.م';               
    final numberFormat = NumberFormat.currency(            
      locale: 'ar_EG', // تنسيق العملة باللغة العربية في مصر                                                    
      symbol: 'ج.م',                                       
      decimalDigits: 2,                                  
    );                                                   
    // تحويل القيمة إلى رقم double قبل التنسيق           
    return numberFormat.format((amount as num).toDouble());                                                 
  }                                                                                                         
                                                                                                          
  // ----------------------------------------------------------------------                                 
  // دالة تنسيق التاريخ                                
  // ----------------------------------------------------------------------                                 
  String _formatDate(dynamic timestamp) {                
    if (timestamp == null) return '';                                                                         
                                                                                                          
    DateTime date;                                                                                            
    
    // التعامل مع حالات مختلفة: Firestore Timestamp أو ISO String (كما في كود HTML)                           
    if (timestamp is Timestamp) {                          
      date = timestamp.toDate();                         
    } else if (timestamp is String) {                       
      // محاولة تحويل سلسلة ISO إلى DateTime              
      try {                                                  
        date = DateTime.parse(timestamp);                  
      } catch (_) {                                          
        return timestamp; // إذا فشل التحويل، عرض النص كما هو                                                   
      }                                                  
    } else {                                               
      return '';                                         
    }                                                                                                         
    
    final dateFormat = DateFormat.yMMMd('ar_EG'); // مثال: ٢٢ نوفمبر ٢٠٢٥                                     
    return dateFormat.format(date);                    
  }                                                                                                         
                                                                                                          
  // ----------------------------------------------------------------------                                 
  // UI BUILDER                                        
  // ----------------------------------------------------------------------                                                                                      
                                                                                                          
  @override                                            
  Widget build(BuildContext context) {                   
    return Scaffold(                                       
      appBar: AppBar(                                        
        title: const Text('كشف الفواتير الشهرية'),           
        backgroundColor: const Color(0xFF007bff), // أزرق مطابق                                                   
        foregroundColor: Colors.white,                     
      ),                                                   
      body: FutureBuilder<QuerySnapshot>(                    
        future: _invoicesFuture,                             
        builder: (context, snapshot) {                         
          if (snapshot.connectionState == ConnectionState.waiting) {                                                  
            // حالة التحميل                                      
            return Center(                                         
              child: _buildLoadingIndicator('جاري جلب قائمة الفواتير...'),                                            
            );                                                 
          }                                                                                                         
                                                                                                          
          if (snapshot.hasError) {                               
            // حالة الخطأ                                        
            return Center(                                         
              child: _buildErrorWidget(snapshot.error.toString()),                                                    
            );                                                 
          }                                                                                                         
                                                                                                          
          final invoices = snapshot.data?.docs ?? [];                                                               
          
          if (invoices.isEmpty) {                                
            // حالة لا توجد فواتير                               
            return const Center(                                   
              child: Text(                                           
                'لا توجد فواتير سابقة لعرضها.',                      
                style: TextStyle(fontSize: 18, color: Color(0xFF6c757d)),                                               
              ),                                                 
            );                                                 
          }                                                                                                         
                                                                                                          
          // حالة عرض البيانات                                 
          return SingleChildScrollView(                          
            padding: const EdgeInsets.all(20),                   
            child: _buildInvoicesTable(invoices),              
          );                                                 
        },                                                 
      ),                                                 
    );                                                 
  }                                                                                                         
                                                                                                          
  // بناء مؤشر التحميل                                 
  Widget _buildLoadingIndicator(String message) {        
    return Column(                                         
      mainAxisAlignment: MainAxisAlignment.center,         
      children: [                                            
        const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007bff))),            
        const SizedBox(height: 15),                          
        Text(                                                  
          message,                                             
          style: const TextStyle(fontSize: 16, color: Color(0xFF007bff)),                                           
          textAlign: TextAlign.center,                       
        ),                                                 
      ],                                                 
    );                                                 
  }                                                                                                         
                                                                                                          
  // بناء شاشة الخطأ                                   
  Widget _buildErrorWidget(String error) {               
    return Padding(                                        
      padding: const EdgeInsets.all(20.0),                 
      child: Text(                                           
        'حدث خطأ: ${error.contains('الرجاء تسجيل الدخول') ? 'الرجاء تسجيل الدخول أولاً' : 'فشل جلب البيانات.'}',                                                        
        style: const TextStyle(fontSize: 18, color: Colors.red),                                                  
        textAlign: TextAlign.center,                       
      ),                                                 
    );                                                 
  }                                                                                                         
                                                                                                          
  // بناء جدول الفواتير                                
  Widget _buildInvoicesTable(List<QueryDocumentSnapshot> invoices) {                                          
    return Container(                                      
      decoration: BoxDecoration(                             
        border: Border.all(color: const Color(0xFFdee2e6)),                                                       
        borderRadius: BorderRadius.circular(8),              
        // 🛠️ تصحيح deprecated_member_use: استخدام .withAlpha
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4)], // 0.05 * 255 ≈ 12.75 ~ 13
      ),                                                   
      child: ClipRRect(                                      
        borderRadius: BorderRadius.circular(8),              
        child: DataTable(                                      
          columnSpacing: 15,                                   
          dataRowMinHeight: 40,                                
          dataRowMaxHeight: 60,                                
          // 🛠️ تصحيح deprecated_member_use: استبدال MaterialStateProperty بـ WidgetStateProperty
          headingRowColor: WidgetStateProperty.resolveWith((states) => const Color(0xFFe9ecef)),                  
          headingTextStyle: const TextStyle(color: Color(0xFF495057), fontWeight: FontWeight.bold),                 
          columns: const [                                       
            DataColumn(label: Text('تاريخ الإصدار', textAlign: TextAlign.right)),                                     
            DataColumn(label: Text('إجمالي المبلغ', textAlign: TextAlign.right)),                                     
            DataColumn(label: Text('العمولة المحققة', textAlign: TextAlign.right)),                                   
            DataColumn(label: Text('الحالة', textAlign: TextAlign.right)),                                            
            DataColumn(label: Text('الإجراء', textAlign: TextAlign.right)),                                         
          ],                                                   
          rows: invoices.map((doc) => _buildInvoiceRow(doc)).toList(),                                            
        ),                                                 
      ),                                                 
    );                                                 
  }                                                                                                         
                                                                                                          
  // بناء صف الفاتورة                                  
  DataRow _buildInvoiceRow(QueryDocumentSnapshot doc) {                                                       
    final invoice = doc.data() as Map<String, dynamic>;                                                       
    final status = invoice['status'] as String? ?? 'other';                                                   
    final invoiceId = doc.id;                                                                                 
    
    // مطابقة ألوان وحالات الـ CSS                       
    Color rowColor;                                      
    String statusText;                                                                                        
    
    switch (status) {                                      
      case 'pending':                                        
        rowColor = const Color(0xFFfff3cd); // #fff3cd (أصفر فاتح)                                                
        statusText = 'انتظار';                               
        break;                                             
      case 'paid':                                           
        rowColor = const Color(0xFFd4edda); // #d4edda (أخضر فاتح)                                                
        statusText = 'تم السداد';                            
        break;                                             
      case 'cancelled':                                      
        rowColor = const Color(0xFFf8d7da); // #f8d7da (أحمر فاتح)                                                
        statusText = 'ملغاة';                                
        break;                                             
      default:                                               
        rowColor = Colors.white;                             
        statusText = 'أخرى';                             
    }                                                                                                         
                                                                                                          
    final actionText = (status == 'pending') ? 'عرض/سداد' : 'عرض';                                                                                                 
    
    return DataRow(                                        
      // 🛠️ تصحيح deprecated_member_use: استبدال MaterialStateProperty بـ WidgetStateProperty
      color: WidgetStateProperty.resolveWith((states) => rowColor),                                           
      cells: [                                               
        DataCell(Text(_formatDate(invoice['creationDate']))),                                                     
        DataCell(Text(_formatCurrency(invoice['finalAmount']))),                                                  
        DataCell(Text(_formatCurrency(invoice['totalCommission']))),                                              
        DataCell(Text(statusText, style: TextStyle(fontWeight: status == 'pending' ? FontWeight.bold : FontWeight.normal))),                                           
        DataCell(                                              
          InkWell(                                               
            onTap: () {                                            
              // TODO: استبدال هذا برمز فتح صفحة تفاصيل الفاتورة                                                        
              ScaffoldMessenger.of(context).showSnackBar(                                                                 
                SnackBar(content: Text('الانتقال إلى تفاصيل الفاتورة رقم: $invoiceId')),                                
              );                                                 
            },                                                   
            child: Text(                                           
              actionText,                                          
              style: const TextStyle(                                
                color: Color(0xFF007bff), // #007bff                 
                fontWeight: FontWeight.bold,                       
              ),                                                 
            ),                                                 
          ),                                                 
        ),                                                 
      ],                                                 
    );                                                 
  }                                                  
}
