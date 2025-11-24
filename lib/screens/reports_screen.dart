// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_test_app/data_sources/reports_data_source.dart';
import 'package:my_test_app/widgets/report_widgets.dart';
import 'package:my_test_app/widgets/bottom_nav_bar.dart'; // افترض وجود BottomNavBar

// تعريف حالة شاشة التقرير (Loading, Loaded, Error)
enum ReportStatus { initial, loading, loaded, error, noData }

class ReportsScreen extends StatefulWidget {
  final String sellerId; // يجب تمريرها من صفحة تسجيل الدخول/الرئيسية

  const ReportsScreen({super.key, required this.sellerId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsDataSource _dataSource = ReportsDataSource();
  ReportStatus _status = ReportStatus.initial;
  FullReportData? _reportData;
  String _errorMessage = '';

  // مرشحات التاريخ
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // تهيئة مرشحات التاريخ إلى الشهر الحالي (مثلما كان في JS)
    _initializeDateFilters();
    // تحميل البيانات الأولية
    _loadReports();
  }

  void _initializeDateFilters() {
    final now = DateTime.now();
    // تاريخ البداية: اليوم الأول من الشهر الحالي
    _startDate = DateTime(now.year, now.month, 1);
    // تاريخ النهاية: اليوم الأخير من الشهر الحالي
    _endDate = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _loadReports() async {
    if (widget.sellerId.isEmpty) {
      if(mounted) { // 🛠️ تم إضافة الأقواس المعقوفة
        setState(() {
          _status = ReportStatus.error;
          _errorMessage = 'معرّف البائع غير متوفر.';
        });
      } // 🛠️ تم إضافة الأقواس المعقوفة
      return;
    }

    if(mounted) { // 🛠️ تم إضافة الأقواس المعقوفة
      setState(() {
        _status = ReportStatus.loading;
      });
    } // 🛠️ تم إضافة الأقواس المعقوفة

    // إضافة وقت النهاية إلى تاريخ النهاية لضمان شمول اليوم كاملاً (23:59:59)
    final endDateExclusive = _endDate.add(const Duration(hours: 23, minutes: 59, seconds: 59));

    try {
      final data = await _dataSource.loadFullReport(
        widget.sellerId,
        _startDate,
        endDateExclusive,
      );

      if(mounted) { // 🛠️ تم إضافة الأقواس المعقوفة
        setState(() {
          _reportData = data;
          _status = ReportStatus.loaded;
        });
      } // 🛠️ تم إضافة الأقواس المعقوفة

    } catch (e) {
      if(mounted) { // 🛠️ تم إضافة الأقواس المعقوفة
        setState(() {
          if (e.toString().contains('No orders found')) {
            _status = ReportStatus.noData;
          } else {
            _status = ReportStatus.error;
            _errorMessage = 'حدث خطأ أثناء تحميل التقارير: ${e.toString().split(':').last.trim()}';
          }
        });
      } // 🛠️ تم إضافة الأقواس المعقوفة
    }
  }

  // دالة لاختيار التاريخ
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    // 🛠️ تصحيح use_build_context_synchronously (التحقق من mounted قبل استخدام context)
    if (!mounted) return;

    if (picked != null) {
      if (isStartDate) {
        // تأكيد أن تاريخ البداية لا يسبق تاريخ النهاية
        if (picked.isAfter(_endDate)) {
          // رسالة خطأ
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تاريخ البداية يجب أن يكون قبل تاريخ النهاية.')),
          );
          return;
        }
        _startDate = picked;
      } else {
        // تأكيد أن تاريخ النهاية لا يسبق تاريخ البداية
        if (picked.isBefore(_startDate)) {
          // 🛠️ تصحيح use_build_context_synchronously (التحقق من mounted قبل استخدام context)
          if (!mounted) return; 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تاريخ النهاية يجب أن يكون بعد تاريخ البداية.')),
          );
          return;
        }
        _endDate = picked;
      }
      _loadReports(); // إعادة تحميل التقرير بعد تغيير التاريخ
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير المبيعات'),
        backgroundColor: ChartColors.primary,
        automaticallyImplyLeading: false, // لا نريد زر العودة في الـ mobile app
      ),
      // ⭐️ تم إزالة Directionality والاعتماد على الاتجاه العام ⭐️
      body: Padding(
        padding: const EdgeInsets.only(bottom: 10.0), // مسافة للـ BottomNavBar
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDateFilter(),
              const SizedBox(height: 20),
              _buildBodyContent(),
            ],
          ),
        ),
      ),
      // تم حذف const لحل خطأ "Not a constant expression"
      bottomNavigationBar: BottomNavBar(activeIndex: 3), // افترض أن التقارير هي الإيقونة رقم 3
    );
  }

  // بناء مرشحات التاريخ
  Widget _buildDateFilter() {
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Wrap(
          spacing: 15,
          runSpacing: 10,
          // محاذاة العناصر إلى اليمين (RTL)
          alignment: WrapAlignment.end,
          children: [
            _buildDateInput('من تاريخ:', _startDate, true, dateFormat),
            _buildDateInput('إلى تاريخ:', _endDate, false, dateFormat),
            ElevatedButton(
              onPressed: _loadReports,
              style: ElevatedButton.styleFrom(
                backgroundColor: ChartColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              ),
              child: const Text('تطبيق', style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  // ويدجت إدخال التاريخ
  Widget _buildDateInput(String label, DateTime date, bool isStartDate, DateFormat dateFormat) {
    return InkWell(
      onTap: () => _selectDate(context, isStartDate),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFe9ecef)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          // ⭐️ تم إزالة textDirection: TextDirection.rtl للاعتماد على الاتجاه العام ⭐️
          // ترتيب العناصر من اليمين إلى اليسار (لأن الاتجاه العام RTL): أيقونة -> تاريخ -> تسمية
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Color(0xFF6c757d)),
            const SizedBox(width: 5),
            Text(
              dateFormat.format(date),
              style: const TextStyle(color: ChartColors.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // عرض محتوى الصفحة بناءً على حالة التحميل
  Widget _buildBodyContent() {
    switch (_status) {
      case ReportStatus.loading:
        return const Center(child: Padding(
          padding: EdgeInsets.all(50.0),
          child: CircularProgressIndicator(color: ChartColors.primary),
        ));

      case ReportStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(50.0),
            child: Text(
              'خطأ في التحميل: $_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ChartColors.danger, fontSize: 16),
            ),
          ),
        );

      case ReportStatus.noData:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(50.0),
            child: Text(
              'لا توجد بيانات متاحة في الفترة المحددة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6c757d), fontSize: 16),
            ),
          ),
        );

      case ReportStatus.loaded:
        // 🛠️ تم إزالة const غير الضرورية
        if (_reportData == null) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            // 1. بطاقات الإحصائيات
            StatsCardsGrid(overview: _reportData!.overview),

            const SizedBox(height: 20),

            // 2. الرسوم البيانية
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                SizedBox(
                  width: 350, // تحديد عرض ثابت أو نسبة مئوية
                  child: ChartFrame(chart: OrdersStatusChart(report: _reportData!.statusReport)),
                ),
                SizedBox(
                  width: 350,
                  child: ChartFrame(chart: MonthlySalesChart(report: _reportData!.monthlySales)),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. جدول المنتجات الأكثر مبيعاً
            TopProductsTable(products: _reportData!.topProducts),
          ],
        );

      // تم دمج حالتي initial و default لتبسيط التبديل
      case ReportStatus.initial:
      default:
        return const SizedBox.shrink();
    }
  }
}
