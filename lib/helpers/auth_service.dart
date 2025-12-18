// lib/helpers/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // بيانات Firebase الثابتة ورابط AWS للإشعارات
  final String _notificationApiEndpoint = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";

  late final FirebaseAuth _auth;
  late final FirebaseFirestore _db;

  AuthService() {
    _auth = FirebaseAuth.instance;
    _db = FirebaseFirestore.instance;
  }

  /// تسجيل الدخول وتحويل الإيميل الوهمي إلى بيانات تعتمد على رقم الهاتف
  Future<String> signInWithEmailAndPassword(String email, String password) async {
    try {
      // 1. تسجيل الدخول في Firebase Authentication
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user == null) throw Exception("user-null");
      final uid = user.uid;

      // 2. البحث عن البيانات في Firestore باستخدام رقم الهاتف المستخلص من الإيميل
      // الإيميل يكون بصيغة 010xxx@aswaq.com فنأخذ الجزء الأول منه
      String phoneFromEmail = email.split('@')[0];
      final userData = await _getUserDataByPhone(phoneFromEmail);

      final String userRole = userData['role'] is String ? userData['role'] : 'buyer';
      final String userAddress = userData['address'] is String ? userData['address'] : '';
      final String? userFullName = userData['fullname'] is String ? userData['fullname'] : null;
      final String? merchantName = userData['merchantName'] is String ? userData['merchantName'] : null;
      
      // التأكد من جلب رقم الهاتف الصافي المسجل في Firestore
      final String phoneToShow = userData['phone'] is String ? userData['phone'] : phoneFromEmail;

      // توحيد صيغة الموقع الجغرافي
      Map<String, double>? location;
      if (userData['location'] is GeoPoint) {
         final geoPoint = userData['location'] as GeoPoint;
         location = {'lat': geoPoint.latitude, 'lng': geoPoint.longitude};
      } else if (userData['location'] is Map) {
         location = Map<String, double>.from(userData['location'] as Map);
      }
      if (location == null && userData['lat'] is num && userData['lng'] is num) {
          location = {
            'lat': (userData['lat'] as num).toDouble(),
            'lng': (userData['lng'] as num).toDouble(),
          };
      }

      // 3. حفظ البيانات محلياً (نعتمد حقل phone بدلاً من email للواجهات)
      await _saveUserToLocalStorage(
        id: uid,
        role: userRole,
        fullname: userFullName,
        address: userAddress,
        merchantName: merchantName,
        phone: phoneToShow, 
        location: location,
      );

      // 4. تسجيل توكن الإشعارات (AWS)
      final fcmToken = await _requestFCMToken();
      if (fcmToken != null) {
        await _registerFcmEndpoint(uid, fcmToken, userRole, userAddress);
      }

      return userRole;
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw 'auth/unknown-error';
    }
  }

  /// تسجيل الخروج ومسح البيانات المحلية
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('loggedUser');
    } catch (e) {
      debugPrint("🚨 فشل تسجيل الخروج: $e");
    }
  }

  /// البحث عن المستخدم في المجموعات باستخدام حقل phone
  Future<Map<String, dynamic>> _getUserDataByPhone(String phone) async {
    final collections = ['sellers', 'consumers', 'users'];

    for (var collectionName in collections) {
      try {
        final snapshot = await _db
            .collection(collectionName)
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          final data = doc.data() as Map<String, dynamic>;
          
          String role = 'buyer';
          if (collectionName == 'sellers') {
            role = 'seller';
          } else if (collectionName == 'consumers') {
            role = 'consumer';
          } else if (collectionName == 'users' && data.containsKey('role')) {
            role = data['role'] is String ? data['role']! : 'buyer';
          }
          return {...data, 'role': role};
        }
      } catch (e) {
        debugPrint("⚠️ فشل قراءة Firestore في $collectionName: $e");
      }
    }
    return {'role': 'buyer'};
  }

  /// حفظ البيانات في SharedPreferences بنظام "رقم الهاتف"
  Future<void> _saveUserToLocalStorage({
    required String id,
    required String role,
    String? fullname,
    String? address,
    String? merchantName,
    String? phone, 
    Map<String, double>? location,
  }) async {
    final userDataToStore = {
      'id': id,
      'ownerId': id,
      'role': role,
      'fullname': fullname,
      'address': address,
      'merchantName': merchantName,
      'phone': phone, // هنا تم الاستغناء عن الإيميل في التخزين المحلي
      'location': location,
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(userDataToStore);
      await prefs.setString('loggedUser', jsonString);
      debugPrint("💾 تم حفظ بيانات العميل (رقم الهاتف) بنجاح: $jsonString");
    } catch (e) {
      debugPrint("🚨 خطأ في SharedPreferences: $e");
    }
  }

  Future<String?> _requestFCMToken() async {
    try {
      if (kIsWeb) return null;
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint("⚠️ FCM Token failed: $e");
      return null;
    }
  }

  Future<void> _registerFcmEndpoint(String userId, String fcmToken, String userRole, String userAddress) async {
    try {
      final apiData = {
        'userId': userId,
        'fcmToken': fcmToken,
        'role': userRole,
        'address': userAddress
      };

      final response = await http.post(
        Uri.parse(_notificationApiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(apiData),
      );

      if (response.statusCode != 200) {
        debugPrint("⚠️ AWS Endpoint Failure: ${response.statusCode}");
      }
    } catch (err) {
      debugPrint("⚠️ AWS API Error: $err");
    }
  }
}
