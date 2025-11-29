// lib/models/seller_dashboard_data.dart (مُعدَّل)

class SellerDashboardData {                       
  final int totalOrders;
  final double completedSalesAmount;
  final int pendingOrdersCount;
  final int newOrdersCount; 
  // 🟢🟢 الحقل الجديد 🟢🟢
  final String sellerName; // تم إضافة اسم البائع هنا
    
  SellerDashboardData({
    required this.totalOrders,
    required this.completedSalesAmount,             
    required this.pendingOrdersCount,
    required this.newOrdersCount,
    // 🟢 إضافة المتطلب الجديد
    required this.sellerName,
  });

  // نموذج بيانات فارغ/تحميل (تم التعديل)
  factory SellerDashboardData.loading() {
    return SellerDashboardData(                       
      totalOrders: 0,
      completedSalesAmount: 0.0,                      
      pendingOrdersCount: 0,
      newOrdersCount: 0, 
      // 🟢 إضافة القيمة الافتراضية
      sellerName: 'جاري التحميل...',
    );
  }                                             
}
