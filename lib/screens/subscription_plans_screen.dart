import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionPlansScreen extends StatelessWidget {
  const SubscriptionPlansScreen({super.key});

  Future<void> _processPayment(BuildContext context, String planName, double price) async {
    // رابط الدفع التجريبي أو الربط مع EC2 لاحقاً
    final String paymentLink = "https://your-payment-gateway.com/pay?amount=$price";
    if (await canLaunchUrl(Uri.parse(paymentLink))) {
      await launchUrl(Uri.parse(paymentLink), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عذراً، تعذر فتح بوابة الدفع')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('باقات الاشتراك المتاحة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2c3e50),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('subscription_plans').orderBy('price').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد باقات متاحة حالياً', style: TextStyle(fontFamily: 'Cairo')));
          }

          final plans = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final planId = plans[index].id;
              final plan = plans[index].data() as Map<String, dynamic>;
              
              // استخراج المصفوفة المعقدة للمميزات
              final List<dynamic> features = plan['features'] ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  children: [
                    // الجزء العلوي: اسم الباقة والسعر
                    Container(
                      padding: const EdgeInsets.all(25),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: plan['price'] > 0 ? const Color(0xFFB21F2D) : const Color(0xFF34495e),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            plan['planName'] ?? 'باقة',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${plan['price']}',
                                style: const TextStyle(color: Color(0xFFf1c40f), fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                              const Text(' ج.م', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Cairo')),
                            ],
                          ),
                          Text(
                            'لمدة ${plan['durationDays']} يوم',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                    ),
                    
                    // قائمة المميزات الذكية (بناءً على الـ Array والـ Map)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: features.map((featureMap) {
                          final bool isAvailable = featureMap['value'] ?? false;
                          final String label = featureMap['label'] ?? "";

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  isAvailable ? Icons.check_circle : Icons.cancel,
                                  color: isAvailable ? Colors.green : Colors.red.shade300,
                                  size: 22,
                                ),
                                const SizedBox(width: 15),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontFamily: 'Cairo',
                                    color: isAvailable ? Colors.black87 : Colors.grey,
                                    decoration: isAvailable ? null : TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // زر الاشتراك
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
                      child: ElevatedButton(
                        onPressed: () => _processPayment(context, plan['planName'], (plan['price'] as num).toDouble()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: plan['price'] > 0 ? const Color(0xFFB21F2D) : const Color(0xFF27ae60),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 2,
                        ),
                        child: Text(
                          plan['price'] > 0 ? 'اشترك الآن' : 'تفعيل الباقة مجاناً',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
