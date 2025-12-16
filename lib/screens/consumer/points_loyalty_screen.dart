import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart'; // استيراد الويدجت للشريط السفلي

class PointsLoyaltyScreen extends StatefulWidget {
  static const routeName = '/points-loyalty';
  const PointsLoyaltyScreen({super.key});

  @override
  State<PointsLoyaltyScreen> createState() => _PointsLoyaltyScreenState();
}

class _PointsLoyaltyScreenState extends State<PointsLoyaltyScreen> {
  bool _isRedeeming = false;
  final String _redeemApiUrl = "https://mtvpdys0o9.execute-api.us-east-1.amazonaws.com/dev/redeempoint";

  final Color primaryBlue = const Color(0xFF2196F3);
  final Color accentYellow = const Color(0xFFFFC107);
  final Color successGreen = const Color(0xFF4CAF50);

  Future<void> _redeemPoints(int pointsToRedeem, double cashEquivalent) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isRedeeming = true);

    try {
      final response = await http.post(
        Uri.parse(_redeemApiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": user.uid,
          "pointsToRedeem": pointsToRedeem,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ تم الاستبدال بنجاح! تم إضافة ${data['cashAdded']} جنيه")),
        );
      } else {
        throw data['error'] ?? 'فشل الاستبدال';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⛔️ خطأ: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isRedeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFf4f7f6),
        appBar: AppBar(
          title: const Text('نقاطي - برنامج الولاء'),
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('consumers').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            
            // 💡 معالجة تضارب الأسماء: قراءة points أو loyaltyPoints
            final int pointsField = data['points'] ?? 0;
            final int loyaltyPointsField = data['loyaltyPoints'] ?? 0;
            final int currentPoints = pointsField > 0 ? pointsField : loyaltyPointsField;

            final double cashbackBalance = (data['cashbackBalance'] ?? 0).toDouble();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildSummaryCard(
                    title: "رصيد نقاط الولاء الحالي",
                    value: "$currentPoints",
                    unit: "نقطة",
                    icon: FontAwesomeIcons.star,
                    gradient: const [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                  ),
                  const SizedBox(height: 15),
                  _buildSummaryCard(
                    title: "رصيد المحفظة (كاش باك)",
                    value: cashbackBalance.toStringAsFixed(2),
                    unit: "جنيه مصري",
                    icon: FontAwesomeIcons.moneyBillWave,
                    gradient: [primaryBlue, const Color(0xFF50a0f0)],
                  ),
                  const SizedBox(height: 25),

                  _buildSectionHeader(Icons.sync_alt, "استبدال النقاط"),
                  _buildRedemptionArea(currentPoints),

                  const SizedBox(height: 25),
                  _buildSectionHeader(Icons.help_outline, "كيف تكسب النقاط؟"),
                  _buildEarningRules(),
                ],
              ),
            );
          },
        ),
        // 🆕 إضافة الشريط السفلي ليعطي طابع التطبيقات الحديثة
        bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: -1), 
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String value, required String unit, required IconData icon, required List<Color> gradient}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: gradient, begin: Alignment.centerRight, end: Alignment.centerLeft),
        boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10, top: -10,
            child: Icon(icon, size: 100, color: Colors.white.withOpacity(0.1)),
          ),
          Column(
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
              Text(unit, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: accentYellow, size: 24),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue)),
        const Expanded(child: Divider(indent: 10, thickness: 1)),
      ],
    );
  }

  Widget _buildRedemptionArea(int currentPoints) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('appSettings').doc('points').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final settings = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final rate = settings['conversionRate'] ?? {};

        final int reqPoints = rate['pointsRequired'] ?? 100;
        final double cashVal = (rate['cashEquivalent'] ?? 1).toDouble();
        final int minPoints = rate['minPointsForRedemption'] ?? 100;

        bool canRedeem = currentPoints >= minPoints;

        return Container(
          margin: const EdgeInsets.only(top: 15),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              Text("كل $reqPoints نقطة = $cashVal جنيه مصري", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("الحد الأدنى للاستبدال: $minPoints نقطة", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isRedeeming || !canRedeem) ? null : () => _redeemPoints(reqPoints, cashVal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.all(15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isRedeeming
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(canRedeem ? "استبدل نقاطي الآن" : "نقاطك غير كافية", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEarningRules() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('appSettings').doc('points').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text("لا توجد قواعد لكسب النقاط حالياً.", style: TextStyle(color: Colors.grey)),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final List<dynamic> rules = data['earningRules'] ?? [];
        final activeRules = rules.where((rule) => rule['isActive'] == true).toList();

        if (activeRules.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text("لا توجد قواعد لكسب النقاط حالياً.", style: TextStyle(color: Colors.grey)),
          );
        }

        return Column(
          children: activeRules.map((rule) {
            String ruleDescription = '';
            IconData iconData = Icons.info_outline;

            switch (rule['type']) {
              case 'per_currency_unit':
                ruleDescription = "اكسب ${rule['value']} نقطة على كل جنيه مصري تنفقه.";
                iconData = FontAwesomeIcons.coins;
                break;
              case 'on_specific_product':
                ruleDescription = "اكسب ${rule['value']} نقطة عند شراء المنتج: ${rule['targetId']}.";
                iconData = FontAwesomeIcons.tag;
                break;
              case 'on_category_purchase':
                ruleDescription = "اكسب ${rule['value']} نقطة عند الشراء من فئة: ${rule['targetId']}.";
                iconData = FontAwesomeIcons.boxesStacked;
                break;
              case 'on_new_customer_registration':
                ruleDescription = "احصل على ${rule['value']} نقطة مجانية عند التسجيل لأول مرة.";
                iconData = FontAwesomeIcons.userPlus;
                break;
              default:
                ruleDescription = rule['description'] ?? 'قاعدة كسب نقاط';
            }

            return Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
              ),
              child: Row(
                children: [
                  Icon(iconData, color: primaryBlue, size: 18),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      ruleDescription,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF333333), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
