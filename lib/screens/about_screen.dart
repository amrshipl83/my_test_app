// المسار: lib/screens/about_screen.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // لاستخدام روابط التواصل الاجتماعي

// 🚨 ملاحظة: يجب تعريف هذه الشاشة في main.dart على المسار '/about'
// routes: { 
//   '/about': (context) => const AboutScreen(),
// }

// 🟢 تعريف الألوان مباشرة
const Color _primaryColor = Color(0xFF2c3e50); // لون Header الخلفي الداكن
const Color _accentColor = Color(0xFF4CAF50);  // اللون الأخضر المميز

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const routeName = '/about';

  @override
  Widget build(BuildContext context) {
    // التأكد من أن الاتجاه هو من اليمين لليسار
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('عن أسواق أكسب'),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 4,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // قسم الشعار والرسالة الترحيبية (Header Section)
              _buildHeaderSection(context),
              const SizedBox(height: 30),

              // قسم الرسالة الرئيسية (العنصر الجديد المطلوب)
              _buildMainMessage(),
              const SizedBox(height: 30),

              // قسم الرؤية والقيم (Feature Grid)
              _buildFeaturesSection(context),
              const SizedBox(height: 30),

              // قسم التواصل (Call to Action)
              _buildContactSection(context),
              const SizedBox(height: 20),

              // زر العودة للرئيسية (محاكاة لـ "ابدأ التسوق الآن")
              _buildBackButton(context),
            ],
          ),
        ),
      ),
    );
  }

  // 1. قسم الشعار والرسالة الترحيبية
  Widget _buildHeaderSection(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundColor: Colors.white,
          child: Icon(FontAwesomeIcons.store, size: 35, color: _accentColor),
        ),
        const SizedBox(height: 10),
        const Text(
          'أسواق أكسب',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryColor),
        ),
        const SizedBox(height: 5),
        const Text(
          'نسهل عليك التسوق والدليفري',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ],
    );
  }

  // 2. الرسالة الرئيسية - مع دمج النص الاحترافي
  Widget _buildMainMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('من نحن', FontAwesomeIcons.infoCircle),
        
        const Text(
          'منصة أسواق أكسب هي الركيزة الرقمية للتجارة الذكية. نحن لسنا مجرد تطبيق؛ نحن منظومة متكاملة صُممت لتمكين السوق المحلي من خلال ربط المصنعين والموردين مباشرةً بتجار التجزئة، وفي الوقت نفسه ربط تجار التجزئة بالمستهلكين النهائيين بكفاءة عالية.',
          style: TextStyle(fontSize: 15.5, height: 1.8),
          textAlign: TextAlign.justify,
        ),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.justify,
          text: TextSpan(
            style: const TextStyle(fontSize: 15.5, height: 1.8, color: Colors.black),
            children: [
              const TextSpan(
                text: 'مدعومة بأحدث أدوات ',
              ),
              TextSpan(
                text: 'الذكاء الاصطناعي',
                style: TextStyle(fontWeight: FontWeight.bold, color: _accentColor),
              ),
              const TextSpan(
                text: '، توفر "أسواق أكسب" تحليلات متقدمة وإدارة طلبات سلسة، مما يضمن أن تكون كل خطوة في سلسلة التوريد والتسوق محسّنة وذكية ومربحة لجميع الأطراف.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 3. قسم الرؤية والقيم
  Widget _buildFeaturesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('رؤيتنا وقيمنا', FontAwesomeIcons.handshake),
        
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1, // تصميم متجاوب (Responsive)
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // لتمكين التمرير الرئيسي
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 3 / 1, // نسبة العرض للارتفاع للبطاقة
          children: [
            _buildFeatureCard(
              icon: FontAwesomeIcons.checkCircle,
              title: 'الجودة والموثوقية',
              description: 'نلتزم بتقديم أفضل المنتجات والخدمات من شركائنا لضمان رضاك التام.',
            ),
            _buildFeatureCard(
              icon: FontAwesomeIcons.shippingFast,
              title: 'السرعة والراحة',
              description: 'تجربة تسوق سلسة وتوصيل موثوق لباب منزلك، لتوفير وقتك وجهدك.',
            ),
            _buildFeatureCard(
              icon: FontAwesomeIcons.users,
              title: 'دعم المجتمع',
              description: 'نعمل على دعم التجار المحليين والمساهمة في نمو الاقتصاد المجتمعي.',
            ),
            _buildFeatureCard(
              icon: FontAwesomeIcons.mobileAlt,
              title: 'سهولة الاستخدام',
              description: 'تصميم بديهي وواجهة مستخدم بسيطة تجعل التسوق متعة للجميع.',
            ),
          ],
        ),
      ],
    );
  }

  // 4. قسم التواصل
  Widget _buildContactSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('تواصل معنا', FontAwesomeIcons.comments),
        
        const Text(
          'نحن هنا لخدمتك. إذا كان لديك أي استفسارات، اقتراحات، أو تحتاج إلى مساعدة، فلا تتردد في التواصل معنا. فريق دعم "أسواق أكسب" مستعد دائماً للاستماع إليك.',
          style: TextStyle(fontSize: 15.5, height: 1.8, color: Colors.black87),
          textAlign: TextAlign.justify,
        ),
        const SizedBox(height: 20),

        // روابط التواصل الاجتماعي
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // واتساب
            IconButton(
              onPressed: () => _launchExternalUrl('https://wa.me/201021070462'),
              icon: Icon(FontAwesomeIcons.whatsapp, size: 30, color: _accentColor),
              tooltip: 'تواصل معنا عبر واتساب',
            ),
            const SizedBox(width: 20),
            // فيسبوك
            IconButton(
              onPressed: () => _launchExternalUrl('https://www.facebook.com/share/199za9SBSE/'),
              icon: Icon(FontAwesomeIcons.facebookF, size: 30, color: _primaryColor),
              tooltip: 'تابعنا على فيسبوك',
            ),
          ],
        ),
      ],
    );
  }

  // 5. زر العودة للرئيسية
  Widget _buildBackButton(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 40),
        const Text(
          'اكتشف عالم التسوق السهل مع أسواق أكسب اليوم!',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _primaryColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            // العودة إلى شاشة البائع/المشتري (BuyerHomeScreen)
            Navigator.of(context).pushNamedAndRemoveUntil('/buyerHome', (route) => false);
          },
          icon: const Icon(FontAwesomeIcons.shoppingBasket, size: 20, color: Colors.white),
          label: const Text('ابدأ التسوق الآن', style: TextStyle(color: Colors.white, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 5,
          ),
        ),
      ],
    );
  }

  // دالة مساعدة لبناء عنوان القسم
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15.0),
      child: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: _primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryColor),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 80,
              height: 3,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // دالة مساعدة لبناء بطاقة الميزة
  Widget _buildFeatureCard({required IconData icon, required String title, required String description}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 35, color: _accentColor),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _primaryColor),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  // دالة لفتح الروابط الخارجية (تماماً كما فعلنا في سياسة الخصوصية)
  void _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }
}
