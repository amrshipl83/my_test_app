// lib/data_sources/reports_data_source.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // لاستخدام Color
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

// 1. نماذج بيانات التقارير (Data Models)
class SalesOverview {
  final double totalSales;
  final int totalOrders;
  final int productsSold;

  SalesOverview({
    required this.totalSales,
    required this.totalOrders,
    required this.productsSold,
  });
}

class StatusReport {
  final List<String> labels;
  final List<int> counts;

  StatusReport({required this.labels, required this.counts});
}

class MonthlySales {
  final List<String> labels; // مثل "01/2025"
  final List<double> sales;

  MonthlySales({required this.labels, required this.sales});
}

class TopProduct {
  final String name;
  final int quantity;
  final double totalSales;

  TopProduct({
    required this.name,
    required this.quantity,
    required this.totalSales,
  });
}

// نموذج بيانات شامل للتقرير الكامل
class FullReportData {
  final SalesOverview overview;
  final StatusReport statusReport;
  final MonthlySales monthlySales;
  final List<TopProduct> topProducts;

  FullReportData({
    required this.overview,
    required this.statusReport,
    required this.monthlySales,
    required this.topProducts,
  });
}

class ReportsDataSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // تعريف حالات الطلب الثابتة (يجب أن تتطابق مع JavaScript)
  static const Map<String, String> ORDER_STATUSES_MAP = {
    'new-order': 'طلبات جديدة',
    'processing': 'قيد التنفيذ',
    'shipped': 'تم الشحن',
    'delivered': 'تم التوصيل',
    'cancelled': 'ملغاة',
  };

  // الدالة الرئيسية لجلب ومعالجة جميع بيانات التقرير
  Future<FullReportData> loadFullReport(
      String sellerId, DateTime startDate, DateTime endDate) async {
    // 1. تنفيذ الاستعلام من Firebase
    final ordersQuery = _db
        .collection("orders")
        .where("sellerId", isEqualTo: sellerId)
        // ⭐️⭐️ تصحيح استخدام where() باستخدام الوسائط المُسماة ⭐️⭐️
        .where("orderDate", isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where("orderDate", isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    final querySnapshot = await ordersQuery.get();

    if (querySnapshot.docs.isEmpty) {
      // لا ترمي خطأ لتجنب تعطل التطبيق بالكامل إذا لم تكن هناك طلبات، بل أعد تقريرًا فارغًا.
      developer.log('No orders found for seller $sellerId in the selected period.');
      return FullReportData(
        overview: SalesOverview(totalSales: 0.0, totalOrders: 0, productsSold: 0),
        statusReport: StatusReport(labels: [], counts: []),
        monthlySales: MonthlySales(labels: [], sales: []),
        topProducts: [],
      );
    }

    // 2. معالجة البيانات المجمعة
    double totalSales = 0;
    int totalOrders = 0;
    int productsSold = 0;
    final statusCounts = <String, int>{};
    final monthlySales = <String, double>{};
    final productSales = <String, Map<String, dynamic>>{};

    // تهيئة عدادات الحالات إلى صفر
    ORDER_STATUSES_MAP.keys.forEach((status) => statusCounts[status] = 0);

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      // التأكد من أن 'status' هو String و Trimed
      final status = (data['status']?.toString().toLowerCase().trim() ?? 'unknown');

      // أخذ الإجمالي من حقل 'total' والتأكد من أنه num
      final orderTotal = (data['total'] as num?)?.toDouble() ?? 0.0;
      final orderItems = data['items'] as List<dynamic>? ?? [];

      // حساب حالة الطلبات
      if (ORDER_STATUSES_MAP.containsKey(status)) {
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      // حساب نظرة عامة والمبيعات الشهرية (لغير الملغاة)
      if (status != 'cancelled') {
        totalOrders++;
        totalSales += orderTotal;

        // حساب المبيعات الشهرية
        if (data['orderDate'] is Timestamp) {
          final date = (data['orderDate'] as Timestamp).toDate();
          final monthYear = DateFormat('yyyy-MM').format(date);
          monthlySales[monthYear] = (monthlySales[monthYear] ?? 0) + orderTotal;
        }

        // حساب المنتجات الأكثر مبيعاً
        for (var item in orderItems) {
          // استخدام اسم المنتج، أو اسم المنتج المترجم إذا وجد
          final productName = item['name'] ?? item['translatedName'] ?? 'منتج غير معروف';
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          // سعر الوحدة مضروباً في الكمية (إذا كان السعر متوفراً في حقل item)
          final itemPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
          final itemTotal = itemPrice * quantity;

          if (!productSales.containsKey(productName)) {
            productSales[productName] = {'quantity': 0, 'totalSales': 0.0};
          }
          // التأكد من أن القيمة الحالية رقمية قبل الزيادة
          productSales[productName]!['quantity'] = (productSales[productName]!['quantity'] as int) + quantity;
          productSales[productName]!['totalSales'] = (productSales[productName]!['totalSales'] as double) + itemTotal;
          productsSold += quantity;
        }
      }
    }

    // 3. بناء نماذج البيانات النهائية

    // تقرير حالة الطلبات
    final statusReport = _buildStatusReport(statusCounts);

    // تقرير المبيعات الشهرية
    final monthlySalesReport = _buildMonthlySales(monthlySales);

    // تقرير المنتجات الأكثر مبيعاً
    final topProductsReport = _buildTopProducts(productSales);

    // بناء التقرير الكامل
    return FullReportData(
      overview: SalesOverview(
        totalSales: totalSales,
        totalOrders: totalOrders,
        productsSold: productsSold,
      ),
      statusReport: statusReport,
      monthlySales: monthlySalesReport,
      topProducts: topProductsReport,
    );
  }

  // --- دوال مساعدة للبناء ---

  StatusReport _buildStatusReport(Map<String, int> statusCounts) {
    // تصفية الحالات التي لها عدد أكبر من صفر
    final labels = ORDER_STATUSES_MAP.entries
        .where((entry) => (statusCounts[entry.key] ?? 0) > 0)
        .map((entry) => entry.value)
        .toList();

    final counts = ORDER_STATUSES_MAP.keys
        .where((status) => (statusCounts[status] ?? 0) > 0)
        .map((status) => statusCounts[status]!)
        .toList();

    return StatusReport(labels: labels, counts: counts);
  }

  MonthlySales _buildMonthlySales(Map<String, double> monthlySales) {
    final sortedMonths = monthlySales.keys.toList()..sort();

    final labels = sortedMonths.map((monthYear) {
      final date = DateFormat('yyyy-MM').parse(monthYear);
      return DateFormat('MM/yyyy').format(date);
    }).toList();

    final sales = sortedMonths.map((monthYear) => monthlySales[monthYear]!).toList();

    return MonthlySales(labels: labels, sales: sales);
  }

  List<TopProduct> _buildTopProducts(Map<String, Map<String, dynamic>> productSales) {
    final sortedProducts = productSales.entries.map((entry) {
      return TopProduct(
        name: entry.key,
        quantity: entry.value['quantity'] as int,
        totalSales: entry.value['totalSales'] as double,
      );
    }).toList()
    ..sort((a, b) => b.totalSales.compareTo(a.totalSales));

    // يكتفي بأول 5 منتجات
    return sortedProducts.take(5).toList();
  }
}
