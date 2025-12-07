// lib/screens/buyer/wallet_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;             
import '../../providers/cashback_provider.dart';     
// ✅ [التعديل هنا] إضافة استيراد BuyerDataProvider لحل خطأ "isn't a type"
import '../../providers/buyer_data_provider.dart'; 
import '../../theme/app_theme.dart'; // افتراض وجود AppTheme

class WalletScreen extends StatelessWidget {
  // ✅ الإضافة المطلوبة لتصحيح الخطأ "Member not found: 'routeName'."
  static const String routeName = '/wallet'; 

  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldLight,
        body: Column(
          children: [
            // 💡 الرأس العلوي (Top Header)
            _buildTopHeader(context),

            // 💡 محتوى الأهداف
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildCashbackGoalsList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // 🚨 ملاحظة: لا يجب أن نضع شريط التنقل السفلي هنا، بل في BuyerHomeScreen
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    // 💡 استخدام Provider لجلب بيانات رصيد الكاش باك
    final cashbackProvider = Provider.of<CashbackProvider>(context, listen: false);
    // 💡 الآن يمكن التعرف على BuyerDataProvider بسبب الاستيراد
    final buyerData = Provider.of<BuyerDataProvider>(context, listen: false);                             
    return Container(                                      
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen, // استخدام لون ثابت بدلاً من التدرج المعقد
        gradient: const LinearGradient(                        
          colors: [AppTheme.primaryGreen, Color(0xFF0056b3)],                                                       
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [                                           
          BoxShadow(
            color: Colors.black.withOpacity(0.1),                
            blurRadius: 4,
            offset: const Offset(0, 2),                        
          ),
        ],                                                 
      ),
      padding: const EdgeInsets.only(top: 40, bottom: 20, left: 15, right: 15),
      child: Column(                                         
        children: [
          Row(                                                   
            children: [
              IconButton(                                            
                icon: const Icon(Icons.arrow_back, color: Colors.white),                                                  
                onPressed: () => Navigator.of(context).pop(),                                                           
              ),
              const Expanded(                                        
                child: Center(
                  child: Text(
                    'أهدافي للكاش باك',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),                                                   
              const SizedBox(width: 48), // لموازنة زر الرجوع
            ],
          ),

          // رسالة الترحيب
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              // 💡 تم الافتراض أن fullName متاح في BuyerDataProvider
              'أهلاً بك، ${buyerData.loggedInUser?.fullname ?? 'زائر'}!',
              style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.9)),
            ),
          ),
                                                               
          // بطاقة رصيد الكاش باك
          FutureBuilder<double>(
            future: cashbackProvider.fetchCashbackBalance(),                                                          
            builder: (context, snapshot) {
              String balanceText;
              if (snapshot.connectionState == ConnectionState.waiting) {
                balanceText = '...';
              } else if (snapshot.hasError) {
                balanceText = 'خطأ!';
              } else {
                final balance = snapshot.data ?? 0.0;
                balanceText = '${balance.toStringAsFixed(2)} جنيه';
              }

              return Container(                                      
                margin: const EdgeInsets.only(top: 15),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 3,                                     
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'رصيد الكاش باك الحالي:',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    Text(
                      balanceText,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD700), // Gold
                        shadows: [Shadow(blurRadius: 5, color: Colors.black26)],
                      ),
                    ),                                                 
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
                                                       
  // 💡 بناء قائمة الأهداف (Goal Cards)
  Widget _buildCashbackGoalsList() {                     
    return Consumer<CashbackProvider>(
      builder: (context, provider, child) {                  
        return FutureBuilder<List<Map<String, dynamic>>>(                                                           
          future: provider.fetchCashbackGoals(),
          builder: (context, snapshot) {                         
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(30.0),                       
                child: Text('جاري تحميل الأهداف...', style: TextStyle(fontSize: 16)),
              ));
            }

            if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Text('حدث خطأ أثناء تحميل الأهداف: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 16)),
              ));
            }

            final goals = snapshot.data ?? [];

            if (goals.isEmpty) {
              return const Center(child: Padding(                    
                padding: EdgeInsets.all(30.0),
                child: Text('لا توجد أهداف كاش باك متاحة لك حاليًا.', style: TextStyle(fontSize: 16)),
              ));                                                
            }
                                                                 
            return Column(
              children: goals.map((goal) {                           
                return _buildGoalCard(context, goal);
              }).toList(),                                       
            );
          },                                                 
        );
      },
    );                                                 
  }

  Widget _buildGoalCard(BuildContext context, Map<String, dynamic> goal) {                                    
    final double minAmount = goal['minAmount'] ?? 0.0;                                                        
    final double currentProgress = goal['currentProgress'] ?? 0.0;
    final double progressPercentage = (currentProgress / minAmount) * 100;
    final double displayProgress = progressPercentage.clamp(0.0, 100.0);
    // 💡 استخدام Intl
    final String timeRemainingText = intl.DateFormat('yyyy/MM/dd').format(goal['endDate']); 
                                                   
    final progressColor = displayProgress >= 100 ? Colors.green : const Color(0xFFFFC107); // Gold
                                                         
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),                   
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(                                             
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),                        
          ),
        ],
        border: Border(                                        
          right: BorderSide(color: AppTheme.primaryGreen, width: 5),                                              
        ),
      ),                                                   
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(                                                   
            children: [
              const Icon(Icons.star, color: Color(0xFFFFC107)),                                                         
              const SizedBox(width: 8),
              Text(                                                  
                goal['title'] ?? 'هدف كاش باك',
                style: TextStyle(                                      
                  color: AppTheme.primaryGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),                                                 
              ),
            ],                                                 
          ),
          const SizedBox(height: 5),                           
          Text(
            'مطلوب: ${minAmount.toStringAsFixed(2)} جنيه لتحصل على كاش باك: ${goal['value']} ${goal['type'] == 'percentage' ? '%' : 'جنيه'}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF6c757d)),                                         
          ),
          const SizedBox(height: 10),                          
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Colors.red),
              const SizedBox(width: 4),                            
              Text(
                'ينتهي في: $timeRemainingText',                      
                style: const TextStyle(fontSize: 12, color: Colors.red),                                                
              ),
            ],
          ),                                                   
          const SizedBox(height: 15),

          // Progress Bar                                      
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: LinearProgressIndicator(                        
              value: displayProgress / 100,
              backgroundColor: const Color(0xFFe9ecef),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),                                                 
              minHeight: 12,
            ),                                                 
          ),
          const SizedBox(height: 8),

          // Progress Text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'مجموع المشتريات: ${currentProgress.toStringAsFixed(2)} / ${minAmount.toStringAsFixed(2)} جنيه',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                '${displayProgress.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: progressColor,
                  fontWeight: FontWeight.bold,                         
                  fontSize: 14,
                ),
              ),
            ],
          ),

          // Achievement Message                               
          if (displayProgress >= 100)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Center(                                         
                child: Text(
                  'تم تحقيق الهدف! مبروك!',                            
                  style: TextStyle(
                    color: Colors.green,                                 
                    fontWeight: FontWeight.bold,                         
                    fontSize: 14,
                  ),                                                 
                ),
              ),
            ),
        ],                                                 
      ),
    );                                                 
  }
}
