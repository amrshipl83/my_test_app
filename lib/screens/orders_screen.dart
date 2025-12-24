// lib/screens/seller/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/data_sources/order_data_source.dart';
import 'package:my_test_app/models/order_model.dart';
import 'package:my_test_app/services/excel_exporter.dart';
import 'package:my_test_app/screens/invoice_screen.dart';
import 'package:sizer/sizer.dart';

class OrdersScreen extends StatefulWidget {
  final String sellerId;

  const OrdersScreen({super.key, required this.sellerId});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<OrderModel>> _ordersFuture;
  final OrderDataSource _dataSource = OrderDataSource();
  List<OrderModel> _loadedOrders = [];
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _refreshOrders();
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = _dataSource.loadOrders(widget.sellerId, 'seller');
    });
  }

  // مطابقة الألوان مع الحالات الجديدة
  Color _getStatusColor(String status) {
    switch (status) {
      case 'new-order': return Colors.info.shade700;
      case 'processing': return Colors.orange.shade700;
      case 'shipped': return Colors.blue.shade700;
      case 'delivered': return Colors.green.shade700;
      case 'cancelled': return Colors.red.shade700;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('الطلبات الواردة', 
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: const Color(0xFF28A745), // لون Primary في HTML
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.file_download_outlined, color: Colors.white, size: 22.sp),
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<OrderModel>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());

                _loadedOrders = snapshot.data ?? [];
                final filteredList = _selectedFilter == 'all'
                    ? _loadedOrders
                    : _loadedOrders.where((o) => o.status == _selectedFilter).toList();

                if (filteredList.isEmpty) return _buildEmptyState();

                return RefreshIndicator(
                  onRefresh: () async => _refreshOrders(),
                  child: ListView.builder(
                    padding: EdgeInsets.all(3.w),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) => _buildOrderCard(filteredList[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 8.h,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        children: [
          _buildFilterChip('الكل', 'all'),
          _buildFilterChip('طلب جديد', 'new-order'),
          _buildFilterChip('قيد التجهيز', 'processing'),
          _buildFilterChip('تم الشحن', 'shipped'),
          _buildFilterChip('تم التسليم', 'delivered'),
          _buildFilterChip('ملغى', 'cancelled'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _selectedFilter == value;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1.w),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
        selected: isSelected,
        selectedColor: const Color(0xFF28A745),
        onSelected: (val) => setState(() => _selectedFilter = value),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final color = _getStatusColor(order.status);
    return Card(
      margin: EdgeInsets.only(bottom: 2.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(Icons.receipt_long, color: color, size: 18.sp),
        ),
        title: Text(order.buyerDetails.name, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
        subtitle: Text("صافي المطلوب: ${order.totalAmount} ج.م", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11.sp)),
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              children: [
                const Divider(),
                _buildInfoRow(Icons.phone, "الهاتف: ${order.buyerDetails.phone}", Colors.blue),
                _buildInfoRow(Icons.location_on, "العنوان: ${order.buyerDetails.address}", Colors.redAccent),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showOrderDetails(order),
                        icon: const Icon(Icons.list_alt),
                        label: const Text("التفاصيل"),
                      ),
                    ),
                    if (order.status != 'delivered' && order.status != 'cancelled') ...[
                      SizedBox(width: 2.w),
                      Expanded(child: _buildStatusDropdown(order)),
                    ]
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color col) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(children: [
        Icon(icon, size: 14.sp, color: col),
        SizedBox(width: 2.w),
        Expanded(child: Text(text, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  void _showOrderDetails(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        height: 75.h,
        padding: EdgeInsets.all(5.w),
        child: Column(
          children: [
            Text("أصناف الطلب", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: order.items.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(order.items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("الكمية: ${order.items[i].quantity}"),
                  trailing: Text("${order.items[i].unitPrice * order.items[i].quantity} ج.م"),
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 6.h), backgroundColor: const Color(0xFF007BFF)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceScreen(order: order))),
              icon: const Icon(Icons.print, color: Colors.white),
              label: const Text("فتح الفاتورة للطباعة", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(OrderModel order) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50, 
        borderRadius: BorderRadius.circular(10), 
        border: Border.all(color: Colors.grey.shade300)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: order.status,
          isExpanded: true,
          style: TextStyle(fontSize: 10.sp, color: Colors.black87, fontWeight: FontWeight.bold),
          items: const [
            DropdownMenuItem(value: 'new-order', child: Text('طلب جديد')),
            DropdownMenuItem(value: 'processing', child: Text('قيد التجهيز')),
            DropdownMenuItem(value: 'shipped', child: Text('تم الشحن')),
            DropdownMenuItem(value: 'delivered', child: Text('تم التسليم')),
            DropdownMenuItem(value: 'cancelled', child: Text('ملغى')),
          ],
          onChanged: (val) async {
            if (val != null) {
              await _dataSource.updateOrderStatus(order.id, val);
              _refreshOrders();
            }
          },
        ),
      ),
    );
  }

  void _exportToExcel() async {
    try {
      await ExcelExporter.exportOrders(_loadedOrders, 'seller');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تصدير ملف الإكسيل بنجاح")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
    }
  }

  Widget _buildEmptyState() => Center(child: Text("لا توجد طلبات في قسم ${_selectedFilter}", style: TextStyle(fontSize: 12.sp)));
  Widget _buildErrorState(String error) => Center(child: Text("خطأ في الاتصال: $error"));
}

