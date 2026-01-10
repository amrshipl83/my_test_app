import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart'; 
import 'package:google_fonts/google_fonts.dart';
import '../../providers/cashback_provider.dart';
import '../../providers/buyer_data_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buyer_mobile_nav_widget.dart';
import 'gifts_tab.dart'; 

class WalletScreen extends StatelessWidget {
  static const String routeName = '/wallet';
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.pushReplacementNamed(context, '/buyerHome');
        },
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              backgroundColor: AppTheme.primaryGreen,
              elevation: 0,
              title: Text(
                'المحفظة والعروض',
                style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              centerTitle: true,
              bottom: TabBar(
                indicatorColor: Colors.orangeAccent,
                indicatorWeight: 4,
                labelStyle: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: "أهداف الكاش باك"),
                  Tab(text: "هدايا المنطقة"),
                ],
              ),
            ),
            body: SafeArea(
              child: TabBarView(
                children: [
                  _buildCashbackTab(context),
                  const GiftsTab(),
                ],
              ),
            ),
            bottomNavigationBar: BuyerMobileNavWidget(
              selectedIndex: 3,
              onItemSelected: (index) {
                if (index == 3) return;
                if (index == 0) Navigator.pushReplacementNamed(context, '/traders');
                if (index == 1) Navigator.pushReplacementNamed(context, '/buyerHome');
                if (index == 2) Navigator.pushReplacementNamed(context, '/myOrders');
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashbackTab(BuildContext context) {
    final buyerData = Provider.of<BuyerDataProvider>(context);
    final cashbackProvider = Provider.of<CashbackProvider>(context);

    return Column(
      children: [
        // كارت الترحيب (بما أن الرصيد غير موجود في الـ Provider الحالي، نكتفي بالترحيب)
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(15.sp),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              Text(
                'أهلاً، ${buyerData.loggedInUser?.fullname ?? 'زائر'}',
                style: GoogleFonts.cairo(fontSize: 16.sp, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5.sp),
              Text(
                'اكتشف عروض الكاش باك المتاحة لك',
                style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.white70),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => Provider.of<CashbackProvider>(context, listen: false).fetchAvailableOffers(),
            child: _buildCashbackGoalsList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCashbackGoalsList() {
    return Consumer<CashbackProvider>(
      builder: (context, provider, _) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: provider.fetchAvailableOffers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final goals = snapshot.data ?? [];
            if (goals.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_offer_outlined, size: 50.sp, color: Colors.grey),
                    Text('لا توجد عروض نشطة حالياً', style: GoogleFonts.cairo(fontSize: 15.sp, color: Colors.grey)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: EdgeInsets.all(12.sp),
              itemCount: goals.length,
              itemBuilder: (context, index) => _buildGoalCard(goals[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    // استخدام المفاتيح كما هي في fetchAvailableOffers بالضبط
    bool isCumulative = goal['goalBasis'] == 'cumulative_spending';
    double minAmount = (goal['minAmount'] ?? 0.0).toDouble();
    double currentProgress = (goal['currentProgress'] ?? 0.0).toDouble();
    
    double progressPercent = minAmount > 0 ? (currentProgress / minAmount) : 0.0;
    if (progressPercent > 1.0) progressPercent = 1.0;
    
    Color progressColor = progressPercent >= 1.0 ? Colors.green : Colors.orange;

    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12.sp),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(12.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goal['description'] ?? 'عرض كاش باك',
                    style: GoogleFonts.cairo(fontSize: 15.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                  ),
                ),
                Text(
                  '${goal['value']} ${goal['type'] == 'percentage' ? '%' : 'ج'}',
                  style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Colors.orange),
                ),
              ],
            ),
            
            SizedBox(height: 5.sp),
            
            Text(
              isCumulative 
                ? "هدف تراكمي: اشترِ بمجموع ${goal['minAmount']} ج"
                : "عرض فوري: لكل طلب بقيمة ${goal['minAmount']} ج",
              style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.black54),
            ),

            if (isCumulative) ...[
              SizedBox(height: 12.sp),
              LinearProgressIndicator(
                value: progressPercent,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
              SizedBox(height: 5.sp),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المحقَّق: ${currentProgress.toStringAsFixed(0)} ج', 
                    style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.grey[600])),
                  Text('%${(progressPercent * 100).toStringAsFixed(0)}', 
                    style: GoogleFonts.cairo(fontSize: 12.sp, color: progressColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ],

            Divider(height: 20.sp, color: Colors.grey[100]),

            Row(
              children: [
                Icon(Icons.access_time_filled, size: 14.sp, color: Colors.redAccent),
                SizedBox(width: 5.sp),
                Text(
                  "متبقي ${goal['daysRemaining']} يوم",
                  style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  goal['sellerName'] ?? 'كل التجار',
                  style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.blueGrey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
