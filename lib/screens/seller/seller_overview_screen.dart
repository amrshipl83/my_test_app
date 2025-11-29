// lib/screens/seller/seller_overview_screen.dart (شاشة لوحة تحكم البائع/نظرة عامة)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
// ⚠️ تأكد من أن Controller/Model موجودين في مساراتهم الصحيحة

class SellerOverviewScreen extends StatelessWidget {
  const SellerOverviewScreen({super.key});

  // ⭐️ دالة مساعدة لبناء كارت الإحصائيات ⭐️
  Widget _buildStatCard(BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    // 💡 استخدام CardColor من الثيم (للتوافق مع الوضع الداكن/الفاتح)
    final cardColor = Theme.of(context).cardColor; 
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. قراءة بيانات الكنترولر (الذي تم تصحيحه)
    final controller = Provider.of<SellerDashboardController>(context);
    final data = controller.data;

    // 2. عرض شاشة تحميل إذا كانت البيانات قيد التحميل
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 3. عرض رسالة خطأ إذا وُجدت
    if (controller.errorMessage != null) {
      return Center(
        child: Text(
          controller.errorMessage!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    // 4. بناء هيكل الإحصائيات (الكارتات)
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⭐️ رسالة ترحيب (تستخدم الاسم الذي تم تصحيحه في الكنترولر)
          Text(
            controller.welcomeMessage,
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),

          // ⭐️ شبكة الكارتات (Dashboard Cards Grid)
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true, 
            physics: const NeverScrollableScrollPhysics(), 
            children: [
              // الكارت 1: إجمالي المبيعات المكتملة
              _buildStatCard(
                context,
                title: 'إجمالي المبيعات المكتملة',
                value: '${data.completedSalesAmount.toStringAsFixed(2)} ر.س',
                icon: Icons.monetization_on,
                color: Colors.green.shade700,
              ),
              // الكارت 2: إجمالي الطلبات
              _buildStatCard(
                context,
                title: 'إجمالي الطلبات',
                value: data.totalOrders.toString(),
                icon: Icons.receipt_long,
                color: Colors.blue.shade700,
              ),
              // الكارت 3: طلبات جديدة
              _buildStatCard(
                context,
                title: 'طلبات جديدة',
                value: data.newOrdersCount.toString(),
                icon: Icons.notifications_active,
                color: Colors.red.shade700,
              ),
              // الكارت 4: طلبات قيد التنفيذ
              _buildStatCard(
                context,
                title: 'طلبات قيد التنفيذ',
                value: data.pendingOrdersCount.toString(),
                icon: Icons.access_time,
                color: Colors.orange.shade700,
              ),
            ],
          ),
          const SizedBox(height: 40),
          
          // ⭐️ قسم المناطق الجغرافية (لتأكيد جلب البيانات الأخرى)
          Text(
            'مناطق التوصيل المختارة',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (controller.sellerData?['deliveryAreas'] != null && (controller.sellerData!['deliveryAreas'] as List).isNotEmpty)
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: (controller.sellerData!['deliveryAreas'] as List)
                  .map((area) => Chip(
                        label: Text(area['name'] ?? area['id'] ?? 'منطقة غير مسماة'),
                      ))
                  .toList(),
            )
          else
            const Text('لم يتم تحديد مناطق توصيل بعد.'),
        ],
      ),
    );
  }
}
