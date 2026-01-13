import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart'; 
import 'package:my_test_app/widgets/buyer_category_ads_banner.dart';
import 'package:sizer/sizer.dart';

class ConsumerCategoryScreen extends StatefulWidget {
  final String mainCategoryId;
  final String categoryName;

  const ConsumerCategoryScreen({
    super.key,
    required this.mainCategoryId,
    required this.categoryName,
  });

  @override
  State<ConsumerCategoryScreen> createState() => _ConsumerCategoryScreenState();
}

class _ConsumerCategoryScreenState extends State<ConsumerCategoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF66BB6A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.categoryName,
            style: TextStyle(color: const Color(0xFF2E7D32), fontWeight: FontWeight.w900, fontSize: 16.sp),
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 15),
              // 1. بانر الإعلانات الخاص بالقسم
              BuyerCategoryAdsBanner(categoryId: widget.mainCategoryId),
              
              const SizedBox(height: 20),
              const ConsumerSectionTitle(title: 'التصنيفات المتاحة'),
              
              // 2. شبكة الأقسام الفرعية (النسخة الخاصة بالمستهلك)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: _buildConsumerSubGrid(),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
        // 3. الشريط السفلي للمستهلك بأيقونات واضحة
        bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: 1), // الـ Index 1 للأقسام
      ),
    );
  }

  // ويدجت شبكة الأقسام الفرعية مدمجة هنا للتبسيط حالياً
  Widget _buildConsumerSubGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subCategory')
          .where('mainCategoryId', isEqualTo: widget.mainCategoryId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 0.9,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () {
                // 🎯 هنا الربط المستقبلي لصفحة منتجات المستهلك
                print("الذهاب لمنتجات القسم الفرعي: ${data['name']}");
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.network(data['imageUrl'], fit: BoxFit.cover, width: double.infinity),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        data['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
