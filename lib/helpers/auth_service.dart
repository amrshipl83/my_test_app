// lib/helpers/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String _notificationApiEndpoint = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _db;

  AuthService() {
    _auth = FirebaseAuth.instance;
    _db = FirebaseFirestore.instance;
  }

  Future<String> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user == null) throw Exception("user-null");

      // البحث عن بيانات المستخدم كاملة
      final userData = await _getUserDataByEmail(email);

      final String userRole = userData['role'];
      final String userAddress = userData['address'] ?? '';
      final String? userFullName = userData['fullname'] ?? userData['fullName'];
      final String? merchantName = userData['merchantName'];
      final String phoneToShow = userData['phone'] ?? email.split('@')[0];
      
      // 🎯 جلب اللوكيشن {lat, lng} من الفايرستور
      final dynamic userLocation = userData['location'];

      // حفظ كل البيانات بما فيها اللوكيشن في الذاكرة المحلية
      await _saveUserToLocalStorage(
        id: user.uid,
        role: userRole,
        fullname: userFullName,
        address: userAddress,
        merchantName: merchantName,
        phone: phoneToShow,
        location: userLocation, // تمرير اللوكيشن هنا
      );

      return userRole;
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw 'auth/unknown-error';
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint("🧹 الذاكرة نظيفة تماماً");
    } catch (e) {
      debugPrint("🚨 فشل الخروج: $e");
    }
  }

  Future<Map<String, dynamic>> _getUserDataByEmail(String email) async {
    final collections = ['sellers', 'consumers', 'users'];
    for (var colName in collections) {
      try {
        final snap = await _db.collection(colName).where('email', isEqualTo: email).limit(1).get();
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          String role = 'buyer';

          if (colName == 'sellers') {
            role = 'seller';
          } else if (colName == 'consumers') {
            role = 'consumer';
          } else if (colName == 'users') {
            role = 'buyer';
          }

          return {...data, 'role': role};
        }
      } catch (e) {
        debugPrint("⚠️ خطأ في قراءة $colName: $e");
      }
    }
    return {'role': 'buyer'};
  }

  Future<void> _saveUserToLocalStorage({
    required String id,
    required String role,
    String? fullname,
    String? address,
    String? merchantName,
    String? phone,
    dynamic location, // 📍 إضافة اللوكيشن هنا
  }) async {
    final data = {
      'id': id,
      'ownerId': id,
      'role': role,
      'fullname': fullname,
      'address': address,
      'merchantName': merchantName,
      'phone': phone,
      'location': location, // 🎯 سيتم حفظه داخل الـ JSON
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loggedUser', json.encode(data));
    debugPrint("✅ تم حفظ بيانات المستخدم واللوكيشن بنجاح");
  }

  // الدوال الإضافية (FCM) تبقى كما هي...
  Future<String?> _requestFCMToken() async { try { return await FirebaseMessaging.instance.getToken(); } catch (e) { return null; } }
  Future<void> _registerFcmEndpoint(String userId, String fcmToken, String userRole, String userAddress) async {
    try {
      final apiData = { 'userId': userId, 'fcmToken': fcmToken, 'role': userRole, 'address': userAddress };
      await http.post(Uri.parse(_notificationApiEndpoint), headers: {'Content-Type': 'application/json'}, body: json.encode(apiData));
    } catch (e) { debugPrint("⚠️ AWS Error: $e"); }
  }
}
