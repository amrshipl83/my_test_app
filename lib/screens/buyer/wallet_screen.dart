// lib/screens/buyer/wallet_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart'; 
import 'package:google_fonts/google_fonts.dart';
import '../../providers/cashback_provider.dart';
import '../../providers/buyer_data_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buyer_mobile_nav_widget.dart';
import 'gifts_tab.dart'; // تأكد أن الملف موجود في نفس المجلد

class WalletScreen extends StatelessWidget {
  static const String routeName = '/wallet';
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // تبويبين: كاش باك وهدايا
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
                style: GoogleFonts.cairo(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              centerTitle: true,
              bottom: TabBar(
                indicatorColor: Colors.orangeAccent,
                indicatorWeight: 4,
                labelStyle: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: "أهداف الكاش باك"),
                  Tab(text: "هدايا المنطقة"),
                ],
              ),
            ),
            body: SafeArea(
              child: TabBarView(
                children: [
                  _buildCashbackTab(context), // محتوى الكاش باك الحالي
                  const GiftsTab(),           // محتوى الهدايا من الملف الخارجي
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

  // --- تبويب الكاش باك (تم تحويله لدالة ليبقى الملف منظماً) ---
  Widget _buildCashbackTab(BuildContext context) {
    final buyerData = Provider.of<BuyerDataProvider>(context);
    final cashbackProvider = Provider.of<CashbackProvider>(context);

    return Column(
      children: [
        // كارت الرصيد العلوي
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(18.sp),
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
                style: GoogleFonts.cairo(fontSize: 16.sp, color: Colors.white70),
              ),
              SizedBox(height: 12.sp),
              _buildBalanceCard(cashbackProvider),
            ],
          ),
        ),
        
        // قائمة الأهداف
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => Provider.of<CashbackProvider>(context, listen: false).fetchCashbackGoals(),
            child: _buildCashbackGoalsList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(CashbackProvider provider) {
    return FutureBuilder<double>(
      future: provider.fetchCashbackBalance(),
      builder: (context, snapshot) {
        double balance = snapshot.data ?? 0.0;
        return Container(
          padding: EdgeInsets.all(15.sp),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('رصيد متاح:', style: GoogleFonts.cairo(fontSize: 17.sp, color: Colors.white)),
              Text(
                '${balance.toStringAsFixed(2)} ج',
                style: GoogleFonts.cairo(fontSize: 22.sp, fontWeight: FontWeight.w900, color: const Color(0xFFFFD700)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCashbackGoalsList() {
    return Consumer<CashbackProvider>(
      builder: (context, provider, _) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: provider.fetchCashbackGoals(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final goals = snapshot.data ?? [];
            if (goals.isEmpty) {
              return Center(child: Text('لا توجد أهداف حالياً', style: GoogleFonts.cairo(fontSize: 18.sp)));
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
    double progress = goal['progressPercentage'] ?? 0.0;
    Color progressColor = progress >= 100 ? Colors.green : Colors.orange;

    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 15.sp),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(15.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(goal['title'], style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 8.sp),
            LinearProgressIndicator(
              value: progress / 100,
              minHeight: 10,
              backgroundColor: Colors.grey[100],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
            SizedBox(height: 8.sp),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('التقدم: ${goal['currentProgress']} ج', style: GoogleFonts.cairo(fontSize: 14.sp)),
                Text('%${progress.toStringAsFixed(0)}', style: GoogleFonts.cairo(color: progressColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
