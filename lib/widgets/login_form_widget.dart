// lib/widgets/login_form_widget.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/helpers/auth_service.dart';
import 'package:my_test_app/screens/forgot_password_screen.dart';
// --- إضافات الـ API والإشعارات (نفس شغل الـ HTML) ---
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginFormWidget extends StatefulWidget {
  const LoginFormWidget({super.key});

  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _isLoading = false;
  String? _errorMessage;
  final AuthService _authService = AuthService();

  // 🎯 دالة الـ API المستمدة من الـ HTML لربط AWS
  Future<void> _registerWithAwsApi(String userId, String fcmToken, String role) async {
    const String apiUrl = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
          "fcmToken": fcmToken,
          "role": role,
          "address": "" // اختياري كما في الويب
        }),
      );
      if (response.statusCode == 200) {
        debugPrint("✅ AWS Registration Success");
      }
    } catch (e) {
      debugPrint("❌ AWS Registration Error: $e");
    }
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. تسجيل الدخول الأصلي (بـ AuthService الذي يبحث في الـ 3 مجموعات)
      final String userRole = await _authService.signInWithEmailAndPassword(_email, _password);

      // 🎯 2. تحديث التوكن ونداء الـ API (نفس منطق الويب)
      try {
        String? token = await FirebaseMessaging.instance.getToken();
        String? uid = FirebaseAuth.instance.currentUser?.uid;

        if (token != null && uid != null) {
          // تحديد الكولكشن الصحيح بناءً على الدور المسترجع من AuthService
          String collectionName = (userRole == 'seller') ? 'sellers' : (userRole == 'consumer' ? 'consumers' : 'users');
          
          // تحديث Firestore (لتوثيق التوكن موبايل)
          await FirebaseFirestore.instance.collection(collectionName).doc(uid).set({
            'notificationToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'platform': 'android',
          }, SetOptions(merge: true));

          // استدعاء الـ API الخاص بـ AWS
          await _registerWithAwsApi(uid, token, userRole);
        }
      } catch (fcmError) {
        debugPrint("⚠️ Notification setup failed but logging in: $fcmError");
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم تسجيل الدخول بنجاح! جاري التحويل...', textAlign: TextAlign.center),
          backgroundColor: Color(0xFF43b97f),
          duration: Duration(milliseconds: 1000),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      // 3. التوجيه الأصلي كما كان (للمسار الرئيسي ليتعامل معه AuthWrapper)
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);

    } on String catch (e) {
      String message;
      if (e == 'user-not-found' || e == 'invalid-email') {
        message = 'البريد الإلكتروني غير مسجل.';
      } else if (e == 'wrong-password') {
        message = 'كلمة المرور غير صحيحة.';
      } else {
        message = 'حدث خطأ أثناء تسجيل الدخول.';
      }
      setState(() { _errorMessage = message; _isLoading = false; });
    } catch (e) {
      setState(() { _errorMessage = 'حدث خطأ غير متوقع.'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _InputGroup(
            icon: Icons.mail_outline,
            hintText: 'البريد الإلكتروني',
            validator: (value) {
              if (value == null || value.isEmpty || !value.contains('@')) return 'يرجى إدخال بريد إلكتروني صالح.';
              return null;
            },
            onSaved: (value) => _email = value!,
          ),
          const SizedBox(height: 18),
          _InputGroup(
            icon: Icons.lock_outline,
            hintText: 'كلمة المرور',
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty || value.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.';
              return null;
            },
            onSaved: (value) => _password = value!,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
              child: Text('نسيت كلمة المرور؟', style: TextStyle(fontSize: 13, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(height: 10),
          _buildSubmitButton(),
          const SizedBox(height: 25),
          _buildRegisterLink(),
          if (_errorMessage != null) _buildErrorBox(),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: 250, height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(colors: [Color(0xFF43b97f), Color(0xFF2d9e68)]),
        boxShadow: [BoxShadow(color: const Color(0xFF2d9e68).withOpacity(0.35), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitLogin,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.login, color: Colors.white, size: 18), SizedBox(width: 8), Text('تسجيل الدخول', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('ليس لديك حساب؟', style: TextStyle(fontSize: 14, color: Color(0xFF6c757d))),
      TextButton(onPressed: () => Navigator.of(context).pushNamed('/register'), child: Text('إنشاء حساب', style: TextStyle(fontSize: 14, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))),
    ]);
  }

  Widget _buildErrorBox() {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0x1adc3545), border: Border.all(color: const Color(0xFFdc3545)), borderRadius: BorderRadius.circular(8)),
      child: Text('❌ $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFFdc3545), fontWeight: FontWeight.w500)),
    );
  }
}

class _InputGroup extends StatelessWidget {
  final IconData icon;
  final String hintText;
  final bool isPassword;
  final String? Function(String?) validator;
  final void Function(String?) onSaved;

  const _InputGroup({required this.icon, required this.hintText, required this.validator, required this.onSaved, this.isPassword = false});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onSaved: onSaved,
      validator: validator,
      obscureText: isPassword,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF6c757d), fontSize: 14),
        suffixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 15.0), child: Icon(icon, size: 18, color: Theme.of(context).primaryColor)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
      ),
    );
  }
}
