// lib/models/seller_dashboard_data.dart

class SellerDashboardData {
  final int totalOrders;
  final double completedSalesAmount;
  final int pendingOrdersCount;
  final int newOrdersCount; // لعد الإشعارات

  SellerDashboardData({
    required this.totalOrders,
    required this.completedSalesAmount,
    required this.pendingOrdersCount,
    required this.newOrdersCount,
  });

  // نموذج بيانات فارغ/تحميل
  factory SellerDashboardData.loading() {
    return SellerDashboardData(
      totalOrders: 0,
      completedSalesAmount: 0.0,
      pendingOrdersCount: 0,
      newOrdersCount: 0,
    );
  }
}
