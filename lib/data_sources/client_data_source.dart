// lib/data_sources/client_data_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';

class ClientDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // 🟢 تم التعديل لاستقبال الروابط (URLs) بدلاً من الملفات (Files)
  Future<User?> registerClient({
    required String fullname,
    required String email,
    required String password,
    required String address,
    required String country,
    required String userType,
    Map<String, double>? location,
    String? logoUrl,       // تم التعديل هنا ليتوافق مع الـ Build
    String? crUrl,         // إضافة للسجل التجاري
    String? tcUrl,         // إضافة للبطاقة الضريبية
    String? merchantName,
    String? businessType,
    String? additionalPhone,
  }) async {
    try {
      // 1. إنشاء الحساب في Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      final String userId = userCredential.user!.uid;

      // 2. تجهيز بيانات المستخدم الأساسية
      final Map<String, dynamic> userData = {
        'fullname': fullname,
        'email': email,
        'address': address,
        'location': location,
        'role': userType,
        'country': country,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 3. إضافة البيانات الخاصة بالمورد (Seller)
      if (userType == 'seller') {
        userData['merchantName'] = merchantName;
        userData['businessType'] = businessType;
        userData['additionalPhone'] = additionalPhone;
        userData['logoUrl'] = logoUrl; // حفظ رابط الشعار
        userData['crUrl'] = crUrl;     // حفظ رابط السجل
        userData['tcUrl'] = tcUrl;     // حفظ رابط البطاقة الضريبية
        userData['isVerified'] = false;
      } else {
        userData['isVerified'] = true;
      }

      // 4. تحديد المجموعة المستهدفة بناءً على النوع
      String targetCollectionName;
      if (userType == "seller") {
        targetCollectionName = "pendingSellers";
      } else if (userType == "consumer") {
        targetCollectionName = "consumers";
      } else {
        targetCollectionName = "users"; // لتاجر التجزئة (Buyer)
      }

      // 5. حفظ البيانات في Firestore
      await _firestore.collection(targetCollectionName).doc(userId).set(userData);
      
      // 6. تسجيل التوكن الخاص بالإشعارات
      await _registerFCMTokenApi(userId, userType, address);

      return userCredential.user;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> _registerFCMTokenApi(String userId, String role, String address) async {
    try {
      final fcmToken = await _fcm.getToken();
      if (fcmToken == null) return;
      await http.post(
        Uri.parse("https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId, 
          'fcmToken': fcmToken, 
          'role': role, 
          'address': address
        }),
      );
    } catch (e) {
      // تجاهل الخطأ في الإشعارات لضمان إتمام عملية التسجيل
    }
  }
}
