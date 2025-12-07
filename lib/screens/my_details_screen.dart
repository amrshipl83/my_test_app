// المسار: lib/screens/my_details_screen.dart

import 'package:flutter/material.dart';
// يجب التأكد من تثبيت هاتين المكتبتين في pubspec.yaml
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
// يجب التأكد من تثبيت هذه المكتبات
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

// 🚨 ملاحظة هامة: يجب تعريف هذه الشاشة في ملف main.dart
// routes: { 
//   '/myDetails': (context) => const MyDetailsScreen(),
//   // يجب تعريف مسارات العودة الرئيسية:
//   '/buyerHome': (context) => const BuyerHomeScreen(), 
//   '/consumerHome': (context) => const ConsumerHomeScreen(),
//   '/login': (context) => const LoginScreen(), 
// }


// 🟢 تعريف الألوان مباشرة (Hardcoded)
const Color _primaryColor = Color(0xFF2c3e50); // لون Header الخلفي الداكن
const Color _buttonPrimaryColor = Color(0xFF4CAF50); // اللون الأخضر الأساسي
const Color _deleteButtonColor = Color(0xFFDC3545); // اللون الأحمر للحذف


class MyDetailsScreen extends StatefulWidget {
  const MyDetailsScreen({super.key});

  @override
  State<MyDetailsScreen> createState() => _MyDetailsScreenState();
}

class _MyDetailsScreenState extends State<MyDetailsScreen> {
  // حالة لعرض بيانات المستخدم
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndDisplayProfile();
  }

  // دالة لجلب البيانات بناءً على الدور (محاكاة لمنطق HTML/JS)
  Future<void> _fetchAndDisplayProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    
    // 1. التحقق من تسجيل الدخول
    if (user == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // 2. محاولة جلب دور المستخدم من Firestore أولاً لتحديد المجموعة
    // سنبدأ بمحاولة جلب المستند من مجموعة 'users' (للمشترين/التجار)
    // إذا لم نجده، نحاول جلب الدور من 'consumers' (للمستهلكين)

    String collectionName = 'users'; // الافتراض الأول
    String nameField = 'name'; 

    try {
      DocumentSnapshot docSnap = await FirebaseFirestore.instance.collection(collectionName).doc(user.uid).get();

      // إذا لم يتم العثور عليه في 'users' (المشترين/التجار)، نحاول في 'consumers'
      if (!docSnap.exists) {
        collectionName = 'consumers';
        nameField = 'fullname';
        docSnap = await FirebaseFirestore.instance.collection(collectionName).doc(user.uid).get();
      }

      if (docSnap.exists) {
        final userData = docSnap.data() as Map<String, dynamic>;

        // تعيين حقل الاسم الصحيح
        if (collectionName == 'consumers') {
           nameField = 'fullname';
        } else {
           // للمشترين/التجار، إذا لم يكن هناك 'name'، نستخدم 'fullname' (افتراضي)
           nameField = (userData.containsKey('name') && userData['name'] != null) ? 'name' : 'fullname';
        }

        setState(() {
          _userData = userData;
          _userData?['collectionName'] = collectionName; // حفظ اسم المجموعة لإعادة استخدامه في الحذف
          _userData?['display_name_field'] = nameField; // حفظ اسم حقل الاسم
          _isLoading = false;
        });
      } else {
        // لم يتم العثور على بيانات الحساب في كلا المجموعتين
        print('User data not found in Firestore. Logging out.');
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      print('Error fetching profile: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('حدث خطأ أثناء تحميل بياناتك.')),
        );
      }
    }
  }


  // 2. دالة التعامل مع طلب حذف الحساب (تغيير الحالة إلى inactive)
  Future<void> _handleDeleteAccount() async {
    // عرض نافذة التأكيد (Modal)
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تحذير: حذف الحساب نهائي!', style: TextStyle(color: _deleteButtonColor)),
          content: const Text(
            'أنت على وشك طلب حذف حسابك نهائياً. هذا الإجراء سيجعل حسابك غير نشط ولن تتمكن من تسجيل الدخول مرة أخرى.'
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء', style: TextStyle(color: _primaryColor))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: _deleteButtonColor),
              child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final user = FirebaseAuth.instance.currentUser;
      final collectionName = _userData?['collectionName'] as String?;

      if (user == null || collectionName == null) return;
      
      try {
        await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(user.uid)
            .update({'status': 'inactive'}); // تحديث الحالة إلى غير نشط

        // بعد تغيير الحالة، تسجيل الخروج
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تغيير حالة حسابك إلى غير نشط بنجاح.')),
           );
           // التوجيه لصفحة تسجيل الدخول وإلغاء جميع المسارات السابقة
           Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        print('Error deleting account: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('حدث خطأ أثناء محاولة حذف الحساب.')),
          );
        }
      }
    }
  }

  // 3. دالة العودة للرئيسية الذكية
  void _backToHome() {
    // يجب استبدال هذا المنطق بالدور الفعلي للمستخدم في تطبيقك
    final String? collectionName = _userData?['collectionName'] as String?; 

    if (collectionName == 'consumers') {
      // للمستهلك
      Navigator.of(context).pushNamedAndRemoveUntil('/consumerHome', (route) => false);
    } else {
      // للمشتري والتاجر (buyer/seller)
      Navigator.of(context).pushNamedAndRemoveUntil('/buyerHome', (route) => false);
    }
  }


  @override
  Widget build(BuildContext context) {
    // التأكد من أن الاتجاه هو من اليمين لليسار
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حسابي'),
          backgroundColor: _primaryColor, 
          foregroundColor: Colors.white, // لون الأيقونات والنص
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // رسالة الترحيب
                    Text(
                      'أهلاً بك، ${_userData?[_userData?['display_name_field']] ?? 'مستخدم'}!',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
                    ),
                    const SizedBox(height: 30),
        
                    // معلومات الحساب
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildInfoRow(context, 'اسم المستخدم:', _userData?[_userData?['display_name_field']] ?? 'غير متوفر', FontAwesomeIcons.user),
                            _buildInfoRow(context, 'البريد الإلكتروني:', _userData?['email'] ?? 'غير متوفر', FontAwesomeIcons.envelope),
                            _buildInfoRow(context, 'هاتف المستخدم:', _userData?['phone'] ?? 'غير متوفر', FontAwesomeIcons.phone),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
        
                    // زر حذف الحساب
                    ElevatedButton.icon(
                      onPressed: _handleDeleteAccount,
                      icon: const Icon(FontAwesomeIcons.trashAlt, size: 18, color: Colors.white),
                      label: const Text('حذف الحساب', style: TextStyle(color: Colors.white, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _deleteButtonColor, // اللون الأحمر
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 5,
                      ),
                    ),
        
                    const SizedBox(height: 15),
                    
                    // زر العودة للرئيسية
                    ElevatedButton.icon(
                      onPressed: _backToHome,
                      icon: const Icon(FontAwesomeIcons.arrowRight, size: 18, color: Colors.white),
                      label: const Text('العودة للرئيسية', style: TextStyle(color: Colors.white, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _buttonPrimaryColor, // اللون الأخضر
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 5,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
  
  // دالة مساعدة لبناء صفوف المعلومات
  Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _buttonPrimaryColor),
          const SizedBox(width: 10),
          // تم توسيع النص لملء المساحة المتاحة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.right,
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

