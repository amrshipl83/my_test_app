import 'package:flutter/material.dart';
import 'package:my_test_app/helpers/auth_service.dart';
import 'package:my_test_app/screens/forgot_password_screen.dart';
// --- المكتبات المطلوبة للـ API والإشعارات ---
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
  String _phone = ''; // استخدام الهاتف كما في نسختك الأصلية
  String _password = '';
  bool _isLoading = false;
  String? _errorMessage;
  final AuthService _authService = AuthService();

  // 🎯 دالة الـ ARN اللي جبناها من الـ HTML
  Future<void> _registerWithAwsApi(String userId, String fcmToken, String role) async {
    const String apiUrl = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";
    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
          "fcmToken": fcmToken,
          "role": role,
        }),
      );
    } catch (e) {
      debugPrint("AWS Error: $e");
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
      // 1. تحويل الهاتف لإيميل وهمي وتسجيل الدخول (منطقك الأصلي)
      String fakeEmail = "${_phone.trim()}@aswaq.com";
      final String userRole = await _authService.signInWithEmailAndPassword(fakeEmail, _password);

      // 🎯 2. الدمج: إرسال التوكن لـ AWS و Firestore بناءً على الدور اللي رجع
      try {
        String? token = await FirebaseMessaging.instance.getToken();
        String? uid = FirebaseAuth.instance.currentUser?.uid;

        if (token != null && uid != null) {
          // تحديث الكولكشن الصحيح (sellers, consumers, users)
          String collection = (userRole == 'seller') ? 'sellers' : (userRole == 'consumer' ? 'consumers' : 'users');
          
          await FirebaseFirestore.instance.collection(collection).doc(uid).set({
            'notificationToken': token,
            'platform': 'android',
          }, SetOptions(merge: true));

          // نداء API أمازون
          await _registerWithAwsApi(uid, token, userRole);
        }
      } catch (e) {
        debugPrint("Notification Setup Error: $e");
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم تسجيل الدخول بنجاح!', textAlign: TextAlign.center),
          backgroundColor: Color(0xFF43b97f),
          duration: Duration(milliseconds: 1000),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      // 3. التوجيه الأصلي للـ AuthWrapper
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);

    } catch (e) {
      setState(() {
        _errorMessage = 'بيانات الدخول غير صحيحة';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _InputGroup(
            icon: Icons.phone_android,
            hintText: 'رقم الهاتف',
            validator: (value) => (value == null || value.isEmpty) ? 'مطلوب' : null,
            onSaved: (value) => _phone = value!,
          ),
          const SizedBox(height: 18),
          _InputGroup(
            icon: Icons.lock_outline,
            hintText: 'كلمة المرور',
            isPassword: true,
            validator: (value) => (value == null || value.length < 6) ? 'قصيرة جداً' : null,
            onSaved: (value) => _password = value!,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
              child: Text('نسيت كلمة المرور؟', style: TextStyle(color: Theme.of(context).primaryColor)),
            ),
          ),
          const SizedBox(height: 10),
          _buildSubmitButton(),
          const SizedBox(height: 25),
          _buildRegisterLink(),
          if (_errorMessage != null) Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
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
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitLogin,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white) 
          : const Text('تسجيل الدخول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('ليس لديك حساب؟'),
        TextButton(
          onPressed: () => Navigator.of(context).pushNamed('/register'),
          child: Text('إنشاء حساب', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _InputGroup extends StatelessWidget {
  final IconData icon;
  final String hintText;
  final bool isPassword;
  final FormFieldValidator<String> validator;
  final FormFieldSetter<String> onSaved;

  const _InputGroup({required this.icon, required this.hintText, required this.validator, required this.onSaved, this.isPassword = false});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      obscureText: isPassword,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        suffixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: validator,
      onSaved: onSaved,
    );
  }
}
