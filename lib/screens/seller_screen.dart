// lib/screens/seller_screen.dart

import 'package:flutter/material.dart';         
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 💡 تم إضافة هذا الاستيراد للـ Logout

// الكونترولر والنماذج                          
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:my_test_app/models/seller_dashboard_data.dart';

// نستخدم مسارات وهمية مؤقتاً لتجنب أخطاء Import
// ...

class SellerScreen extends StatelessWidget {
  // ⭐️⭐️ إضافة routeName لتصحيح الخطأ في main.dart ⭐️⭐️
  static const String routeName = '/sellerHome';
  
  const SellerScreen({super.key});              
  @override
  Widget build(BuildContext context) {
    // يجب أن يكون SellerDashboardController مُضافًا في MultiProvider في main.dart
    final controller = Provider.of<SellerDashboardController>(context);

    // هذا هو الهيكل الرئيسي الذي يعادل <body>      
    return Scaffold(
      // 🟢 تم تطبيق الـ M3: لون الخلفية مُدار بواسطة Theme
      body: Row(                                        
        children: [
          // 1. الشريط الجانبي (Sidebar)
          const _SellerSidebar(),
          // 2. منطقة المحتوى الرئيسية (Main Content)
          Expanded(
            child: _MainContent(controller: controller),                                                  
          ),
        ],
      ),
    );
  }                                             
}

// ---------------------------------------------------------------------
// --- A. الشريط الجانبي (Sidebar) Widget ---
// ---------------------------------------------------------------------
class _SellerSidebar extends StatelessWidget {    
  const _SellerSidebar({super.key});                                 
  
  // 💡 دالة تسجيل خروج مخصصة للبائع لمسح بياناته
  void _handleLogout(BuildContext context, SellerDashboardController controller) async {
    // 1. تنفيذ منطق تسجيل الخروج من الكنترولر (إذا كان موجوداً)
    // 2. مسح بيانات المستخدم من الذاكرة المحلية (LoggedUser)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedUser');
    
    // 3. العودة إلى المسار الرئيسي '/'، والذي سيذهب إلى AuthWrapper
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    // منطق الكود لم يتغير
    final controller = Provider.of<SellerDashboardController>(context);                             
    final isDarkMode = controller.isDarkMode;
    final newOrdersCount = controller.data.newOrdersCount;
    
    // 🟢 1. جلب مخطط الألوان
    final colorScheme = Theme.of(context).colorScheme;

    // 🟢 2. تحديد الألوان بناءً على مخطط الألوان
    final primaryColor = colorScheme.primary;
    final sidebarBg = colorScheme.surfaceContainerHighest; 
    final activeBg = primaryColor.withOpacity(0.15);
    
    // قائمة الروابط (تم تحديث الأيقونات إلى MdiIcons)
    final navItems = [
      {'icon': MdiIcons.viewDashboard, 'title': 'نظرة عامة', 'route': '/seller', 'active': true},
      {'icon': MdiIcons.stickerPlus, 'title': 'إضافة عرض', 'route': '/addOffer', 'active': false},                                                    
      {'icon': MdiIcons.tagMultiple, 'title': 'العروض المتاحة', 'route': '/offers', 'active': false},
      {'icon': MdiIcons.cartCheck, 'title': 'الطلبات', 'route': '/sellerorder', 'active': false, 'isOrders': true},
      {'icon': MdiIcons.chartLineVariant, 'title': 'التقارير', 'route': '/seller-reports', 'active': false},
      {'icon': MdiIcons.accountCircle, 'title': 'حسابي', 'route': '/seller-setting', 'active': false},
      // ⭐️⭐️ تم التعديل: استبدال factory بـ domain ⭐️⭐️
      {'icon': MdiIcons.domain, 'title': 'حساب المنصة', 'route': '/aksab', 'active': false},
      {'icon': MdiIcons.shieldAccount, 'title': 'الخصوصية', 'route': '/privacy', 'active': false},
    ];

    return Container(
      width: 260, 
      color: sidebarBg, // 🟢 استخدام اللون الجديد
      padding: const EdgeInsets.symmetric(vertical: 25.0),                                            
      child: Column(
        children: [
          // الشعار
          Padding(                                          
            padding: const EdgeInsets.symmetric(horizontal: 15.0),                                          
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,                                                    
              children: [
                Icon(MdiIcons.cubeOutline, color: primaryColor, size: 35),
                const SizedBox(width: 10),
                Text('أكسب', style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: primaryColor, 
                )),
              ],
            ),                                            
          ),
          const SizedBox(height: 40),

          // تبديل الوضع الليلي
          Padding(                                          
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: TextButton.icon(
              onPressed: controller.toggleDarkMode,
              style: TextButton.styleFrom(
                side: BorderSide(color: colorScheme.outline, width: 1),
                foregroundColor: colorScheme.onSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                minimumSize: const Size(double.infinity, 0),
              ),
              icon: Icon(isDarkMode ? MdiIcons.whiteBalanceSunny : MdiIcons.weatherNight, size: 18),
              label: Text(isDarkMode ? 'الوضع النهاري' : 'الوضع الليلي', style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(height: 20),
                                                          
          // قائمة التنقل
          Expanded(                                         
            child: ListView.builder(                          
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              itemCount: navItems.length,
              itemBuilder: (ctx, index) {
                final item = navItems[index];
                final isActive = item['active'] as bool;
                final isOrdersLink = item['isOrders'] as bool? ?? false;
                final hasNewOrders = isOrdersLink && newOrdersCount > 0;

                final linkColor = hasNewOrders
                    ? colorScheme.onError 
                    : (isActive ? colorScheme.onPrimary : colorScheme.onSurfaceVariant); 
                
                final bgColor = hasNewOrders
                    ? colorScheme.error 
                    : (isActive ? colorScheme.primary : Colors.transparent); 
                
                final iconColor = hasNewOrders                      
                    ? colorScheme.onErrorContainer 
                    : (isActive ? colorScheme.onPrimary : colorScheme.onSurfaceVariant); 
                                                                                             
                return Padding(                                   
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Material(
                    color: bgColor,                                 
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () {
                         // منطق التوجيه (Routing logic) لم يتغير
                         // 💡 لا تستخدم pushNamed هنا إلا إذا كان هذا المشروع يستخدم نافيجيتورز متعددة
                         // إذا كانت الشاشات تعمل كـ Pages في نفس الـ Scaffold:
                         // controller.navigateTo(item['route'] as String); 
                         // إذا كان انتقالاً حقيقياً لشاشة جديدة:
                         Navigator.of(context).pushNamed(item['route'] as String);
                      },
                      borderRadius: BorderRadius.circular(8),                                                         
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                        child: Stack(
                          children: [                                       
                            Row(
                              children: [                                       
                                Icon(item['icon'] as IconData, size: 20, color: iconColor),                                     
                                const SizedBox(width: 15),                                                                      
                                Text(item['title'] as String, style: TextStyle(color: linkColor, fontSize: 16)),                                                              
                              ],
                            ),                                              
                            // شارة الإشعار
                            if (hasNewOrders)                                 
                              Positioned(
                                left: 10,
                                top: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer, 
                                    shape: BoxShape.circle,                                                                         
                                    boxShadow: [BoxShadow(color: Colors.black26.withAlpha(50), blurRadius: 5)], 
                                  ),                                              
                                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                  child: Center(                                    
                                    child: Text(
                                      newOrdersCount.toString(),
                                      style: TextStyle(
                                        color: colorScheme.onError, 
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10                                                                                  
                                      ),
                                    ),                                            
                                  ),
                                ),
                              ),                                          
                          ],
                        ),
                      ),
                    ),                                            
                  ),                                            
                );                                            
              },
            ),
          ),                                    
          // قسم تسجيل الخروج
          Padding(                                          
            padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15.0),                          
            child: GestureDetector(
              onTap: () => _handleLogout(context, controller), // 💡 استخدام دالة _handleLogout المصححة
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(MdiIcons.logout, size: 20, color: colorScheme.onSurface),
                  const SizedBox(width: 10),
                  Text('تسجيل الخروج', style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
                ],
              ),
            ),
          ),                                            
        ],
      ),
    );
  }                                             
}

// ---------------------------------------------------------------------
// --- B. محتوى الواجهة الرئيسية (Main Content) Widget ---                                      
// ---------------------------------------------------------------------
class _MainContent extends StatelessWidget {      
  final SellerDashboardController controller;
                                                  
  const _MainContent({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    // 🟢 جلب مخطط الألوان
    final colorScheme = Theme.of(context).colorScheme;
    
    // 🟢 استخدام ألوان Theme للسطح والنصوص
    final cardBg = colorScheme.surfaceContainerHigh; 
    final textDark = colorScheme.onSurface; 
    final textLight = colorScheme.onSurfaceVariant; 

    return Container(
      padding: const EdgeInsets.all(30.0),            
      color: colorScheme.background, // 🟢 لون خلفية الـ Scaffold
      child: SingleChildScrollView(                     
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [                                       
            // 1. قسم الترحيب
            Container(
              padding: const EdgeInsets.all(30.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),                                                        
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Text(
                    controller.welcomeMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textDark),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'هنا تجد نظرة سريعة على أداء مبيعاتك.',
                    textAlign: TextAlign.center,                    
                    style: TextStyle(fontSize: 16, color: textLight),
                  ),                                            
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 2. بطاقات لوحة التحكم
            if (controller.isLoading)
              Center(child: CircularProgressIndicator(color: colorScheme.primary))
            else if (controller.errorMessage != null)
              Center(
                child: Text('خطأ في التحميل: ${controller.errorMessage}', style: TextStyle(color: colorScheme.error)), 
              )
            else
              _DashboardCards(data: controller.data), // تم حذف isDarkMode
          ],
        ),
      ),
    );
  }                                             
}

// ---------------------------------------------------------------------
// --- C. بطاقات لوحة التحكم (Dashboard Cards) Widget ---
// ---------------------------------------------------------------------
class _DashboardCards extends StatelessWidget {
  final SellerDashboardData data;                 
  // ❌ تم إزالة final bool isDarkMode;
  
  const _DashboardCards({required this.data, super.key}); // تم تعديل البناء
                                                  
  @override                                       
  Widget build(BuildContext context) {
    // 🟢 جلب مخطط الألوان
    final colorScheme = Theme.of(context).colorScheme;

    // 🟢 استخدام ألوان Theme
    final primaryColor = colorScheme.primary;
    final secondaryColor = colorScheme.secondary; 
    final warningColor = colorScheme.tertiary; 
    
    final cardBg = colorScheme.surfaceContainerHigh; 
    final textDark = colorScheme.onSurface; 

    // ... (تنسيق العملة)
    final formatCurrency = NumberFormat.currency(
      locale: 'ar_EG',
      symbol: 'ج.م',
      decimalDigits: 2                              
    );                                          
    // تعريف البطاقات
    final cards = [
      {
        'title': 'إجمالي الطلبات',                      
        'value': data.totalOrders.toString(),
        'icon': MdiIcons.packageVariant,
        'iconColor': colorScheme.secondary, 
        'borderColor': colorScheme.secondary,
      },                                              
      {
        'title': 'إجمالي المبيعات المكتملة',            
        'value': formatCurrency.format(data.completedSalesAmount),                                      
        'icon': MdiIcons.cashCheck, 
        'iconColor': colorScheme.primary, 
        'borderColor': colorScheme.primary,                 
      },
      {
        'title': 'الطلبات قيد التنفيذ',
        'value': data.pendingOrdersCount.toString(),
        'icon': MdiIcons.timerSand, 
        'iconColor': colorScheme.tertiary, 
        'borderColor': colorScheme.tertiary,
      },
    ];                                          
    
    return GridView.builder(
      // 🟢 GridDelegate: تم تغيير الارتفاع لزيادة المساحة العمودية وتقليل التجاوز
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, 
        crossAxisSpacing: 25.0, 
        mainAxisSpacing: 25.0,
        // 🟢 تم زيادة هذا القيمة لمعالجة مشكلة الـ Overflow
        childAspectRatio: 1.5, // 1.5 تعني العرض/الارتفاع = 1.5
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),

      itemCount: cards.length,
      itemBuilder: (ctx, index) {
        final card = cards[index];
        return Container(
          padding: const EdgeInsets.all(20.0), // تقليل الـ Padding قليلاً
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)], 
            border: Border(right: BorderSide(color: card['borderColor'] as Color, width: 8)), 
          ),
          
          // 🟢 الحل الهيكلي للـ Overflow: استخدام Column وتوزيع المساحة
          child: Column(                                    
            crossAxisAlignment: CrossAxisAlignment.start,                                                   
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // توزيع المحتوى عمودياً
            children: [
              Icon(card['icon'] as IconData, size: 30, color: card['iconColor'] as Color), // تقليل حجم الأيقونة قليلاً
              // ❌ تم إزالة SizedBox(height: 15) لتقليل المساحة المهدرة

              // 🟢 استخدام Expanded/Flexible للنص لضمان التكيف إذا لزم الأمر
              Flexible( 
                child: Text(
                  card['title'] as String,                        
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textDark), // تقليل حجم الخط قليلاً
                  overflow: TextOverflow.ellipsis, // لضمان عدم التجاوز
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 5), // مسافة صغيرة بين العنوان والقيمة
              Text(
                card['value'] as String,                        
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textDark), // تقليل حجم الخط قليلاً
              ),
            ],
          ),                                            
        );
      },
    );
  }
}
