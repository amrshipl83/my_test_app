import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_test_app/data_sources/order_data_source.dart';
import 'package:my_test_app/models/order_model.dart';
import 'package:my_test_app/services/excel_exporter.dart';
import 'package:my_test_app/screens/invoice_screen.dart'; 

class OrdersScreen extends StatefulWidget {
  final String userId;
  final String userRole;

  const OrdersScreen({
    super.key,
    required this.userId,
    required this.userRole,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<OrderModel>> _ordersFuture;
  final OrderDataSource _dataSource = OrderDataSource();
  
  List<OrderModel> _loadedOrders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  // 1. جلب الطلبات وإعادة تحميلها
  Future<void> _fetchOrders() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      // 💡 هنا يتم استدعاء دالة جلب الطلبات
      _ordersFuture = _dataSource.loadOrders(widget.userId, widget.userRole);
      _loadedOrders = await _ordersFuture;
    } catch (e) {
      _ordersFuture = Future.error(e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 2. دالة لتغيير لون الكرت حسب حالة الطلب
  Color _getStatusColor(String status) {
    if (status == 'new-order') {
      // تمييز طلبات البائع الجديدة
      return widget.userRole == 'seller' ? Colors.red.shade100 : Colors.blue.shade100;
    } else if (status == 'processing') {
      return Colors.orange.shade100;
    } else if (status == 'delivered' || status == 'completed') {
      return Colors.green.shade50;
    } else if (status == 'cancelled') {
      return Colors.grey.shade300;
    }
    return Colors.white; // اللون الافتراضي
  }

  // 3. دالة مساعدة لعرض صف بيانات عادي (Label: Value)
  Widget _buildDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        // يبدأ من اليمين
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 💡 إضافة Flexible لتجنب تجاوز النص (Overflow) في القيمة
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: const TextStyle(color: Colors.black54),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  // 4. دالة مساعدة جديدة لعرض الملخص المالي (Gross, Discount, Net)
  Widget _buildSummaryRow(String label, double value, {bool isDiscount = false, bool isNet = false}) {
    Color valueColor = Colors.black87;
    if (isDiscount) {
      valueColor = Colors.red.shade600;
    } else if (isNet) {
      valueColor = Theme.of(context).colorScheme.primary; // اللون الأساسي للمبلغ الصافي
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        // يبدأ من اليمين
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${value.toStringAsFixed(2)} جنيه',
            style: TextStyle(
              fontWeight: isNet ? FontWeight.w900 : FontWeight.bold,
              fontSize: isNet ? 18 : 16,
              color: valueColor,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              color: isNet ? Colors.black : Colors.black54,
              fontWeight: isNet ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  // 5. دالة بناء قائمة تغيير الحالة لدور البائع
  Widget _buildStatusDropdown(OrderModel order) {
    // تعطيل القائمة إذا كانت الحالة نهائية
    final bool isDisabled = order.status == 'delivered' || order.status == 'cancelled';

    return DropdownButton<String>(
      value: order.status,
      icon: isDisabled ? const Icon(Icons.lock, size: 18) : const Icon(Icons.arrow_drop_down),
      elevation: 4,
      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
      underline: Container(height: 1, color: Colors.grey.shade300),
      items: const [
        DropdownMenuItem(value: 'new-order', child: Text('طلب جديد')),
        DropdownMenuItem(value: 'processing', child: Text('قيد التجهيز')),
        DropdownMenuItem(value: 'shipped', child: Text('تم الشحن')),
        DropdownMenuItem(value: 'delivered', child: Text('تم التسليم')),
        DropdownMenuItem(value: 'cancelled', child: Text('ملغى')),
      ],
      onChanged: isDisabled
          ? null // تعطيل وظيفة التغيير
          : (String? newStatus) async {
              if (newStatus != null && newStatus != order.status) {
                if (mounted) setState(() => _isLoading = true);

                try {
                  await _dataSource.updateOrderStatus(order.id, newStatus);
                  
                  // 🛠️ تصحيح use_build_context_synchronously 1
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    // ملاحظة: قد تحتاج إلى تحديث order.statusText هنا قبل العرض
                    SnackBar(content: Text('تم تحديث حالة الطلب ${order.id} إلى $newStatus')),
                  );

                  await _fetchOrders(); // إعادة تحميل القائمة لتحديث الواجهة

                } catch (e) {
                  // 🛠️ تصحيح use_build_context_synchronously 2
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل تحديث الحالة: ${e.toString()}')),
                  );
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              }
            },
    );
  }

  // 6. دالة لفتح التفاصيل المنبثقة - تم تحديثها بالكامل
  void _showOrderDetails(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('تفاصيل الطلب: ${order.id}',
              textAlign: TextAlign.right,
              style: TextStyle(color: Theme.of(context).primaryColor)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end, // يبدأ من اليمين
              mainAxisSize: MainAxisSize.min,
              children: [
                // ⭐️ تفاصيل الطلب الأساسية ⭐️
                _buildDetailRow('الحالة:', order.statusText, Theme.of(context).primaryColor),
                _buildDetailRow('التاريخ:', DateFormat('yyyy/MM/dd HH:mm').format(order.orderDate), Colors.black87),

                const Divider(height: 20, thickness: 1),

                // ⭐️ تفاصيل العميل ⭐️
                Text('بيانات العميل:', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.right),
                _buildDetailRow('الاسم:', order.buyerDetails.name, Colors.black87),
                _buildDetailRow('الهاتف:', order.buyerDetails.phone, Colors.black87),
                _buildDetailRow('العنوان:', order.buyerDetails.address, Colors.black87),

                const Divider(height: 20, thickness: 1),

                // ⭐️ الملخص المالي ⭐️
                Text('ملخص الحساب:', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.right),
                _buildSummaryRow('الإجمالي قبل الخصم', order.grossTotal),
                _buildSummaryRow('خصم الكاش باك', order.cashbackApplied, isDiscount: true),
                const SizedBox(height: 5),
                _buildSummaryRow('المبلغ الصافي المطلوب', order.totalAmount, isNet: true),

                const Divider(height: 20, thickness: 1),

                // ⭐️ عناصر الطلب ⭐️
                Text('عناصر الطلب:', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.right),
                // 🛠️ تصحيح unnecessary_to_list_in_spreads
                ...order.items.map((item) => ListTile(
                      leading: item.imageUrl.isNotEmpty
                          ? Image.network(item.imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                          : const Icon(Icons.inventory_2),
                      title: Text(item.name, textAlign: TextAlign.right),
                      subtitle: Text(
                          'الكمية: ${item.quantity} × سعر الوحدة: ${item.unitPrice.toStringAsFixed(2)} ج',
                          textAlign: TextAlign.right),
                      trailing: Text(
                        '${(item.quantity * item.unitPrice).toStringAsFixed(2)} ج',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )),
              ],
            ),
          ),
          actions: [
            // ⭐️ 2. تم تعديل زر عرض الفاتورة للانتقال للصفحة الجديدة ⭐️
            TextButton.icon(
              icon: const Icon(Icons.receipt_long),
              label: const Text('عرض الفاتورة'),
              onPressed: () {
                // لا نحتاج لـ mounted هنا لأننا داخل دالة البناء (builder) لـ showDialog
                Navigator.of(context).pop(); // إغلاق النافذة المنبثقة الحالية

                // الانتقال إلى شاشة الفاتورة مع تمرير بيانات الطلب
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InvoiceScreen(order: order),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  // 7. دالة التصدير إلى Excel
  void _exportToExcel() async {
    if (_loadedOrders.isEmpty) {
      // 🛠️ تصحيح use_build_context_synchronously 3
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد طلبات لتصديرها.')),
      );
      return;
    }

    // استخدام setState هنا لتحديث واجهة المستخدم وبدء مؤشر التحميل
    if(mounted) setState(() => _isLoading = true);

    try {
      await ExcelExporter.exportOrders(_loadedOrders, widget.userRole);
      
      // 🛠️ تصحيح use_build_context_synchronously 4
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير الطلبات بنجاح إلى ملف Excel.')),
      );
    } catch (e) {
      // 🛠️ تصحيح use_build_context_synchronously 5 (غير موجودة في الكود الأصلي لكن يجب وضعها للحماية)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التصدير: ${e.toString()}')),
      );
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String screenTitle = widget.userRole == 'seller' ? 'الطلبات الواردة' : 'طلباتي';
    
    // ⭐️ رسالة التشخيص - يتم بناؤها هنا لاستخدامها في رسائل الخطأ ⭐️
    final String diagnosticMessage = 'الدور: ${widget.userRole} | المعرّف: ${widget.userId}';

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // 8. زر التصدير
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.insert_drive_file, color: Colors.white),
              onPressed: _exportToExcel,
              tooltip: 'تصدير إلى Excel',
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOrders,
        child: FutureBuilder<List<OrderModel>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _loadedOrders.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 50, color: Colors.red),
                      const SizedBox(height: 10),
                      Text('خطأ في تحميل الطلبات: ${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 5),

                      // ⭐️ عرض رسالة التشخيص عند وجود خطأ ⭐️
                      Text(diagnosticMessage, style: TextStyle(color: Colors.black54, fontSize: 12), textAlign: TextAlign.center),
                      const SizedBox(height: 5),
                      
                      // ⭐️ رسالة خاصة بالفهرسة ⭐️
                      const Text(
                          'إذا استمر الخطأ، تحقق من قواعد الأمان والفهارس المركبة (buyer.id و orderDate) في Firebase.',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                          textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      ElevatedButton(
                        onPressed: _fetchOrders,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (_loadedOrders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
                    SizedBox(height: 10),

                    // ⭐️ عرض رسالة التشخيص حتى لو كانت القائمة فارغة ⭐️
                    Text('لا توجد طلبات سابقة.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    Text(diagnosticMessage, style: TextStyle(color: Colors.grey, fontSize: 12)),

                  ],
                ),
              );
            }
            
            // 9. عرض الطلبات في كروت
            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _loadedOrders.length,
              itemBuilder: (context, index) {
                final order = _loadedOrders[index];
                return Card(
                  color: _getStatusColor(order.status),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    onTap: () => _showOrderDetails(order), // فتح التفاصيل المنبثقة

                    // ⭐️ 3. تم تعديل الكارت لتجنب مشكلة الـ Overflow ⭐️
                    title: Text(
                      'رقم الطلب: ${order.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(height: 5),

                        // ⭐️ عرض قائمة تغيير الحالة للبائع، وعرض الحالة فقط للمشتري ⭐️
                        if (widget.userRole == 'seller')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildStatusDropdown(order),
                              const SizedBox(width: 5),
                              const Text('الحالة:'),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(order.statusText, style: TextStyle(fontWeight: FontWeight.bold, color: order.status == 'new-order' ? Colors.red.shade800 : Colors.green.shade800)),
                              const SizedBox(width: 5),
                              const Text('الحالة:'),
                            ],
                          ),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(DateFormat('yyyy/MM/dd').format(order.orderDate)),
                            const SizedBox(width: 5),
                            const Icon(Icons.calendar_today, size: 12),
                          ],
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      // 💡 استخدام SizedBox للتحكم في عرض الـ trailing بشكل صارم (لحل Overflow محتمل)
                      children: [
                        Text(
                          '${order.totalAmount.toStringAsFixed(2)} ج',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                        ),
                        const Text('الإجمالي', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
