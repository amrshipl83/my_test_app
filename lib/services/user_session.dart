// lib/services/user_session.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  static String? userId;      
  static String? ownerId;     
  static String? role;        
  static String? phoneNumber; 
  static String? merchantName; 
  static bool isSubUser = false;

  static bool get isReadOnly => role == 'read_only';
  static bool get canEdit => role == 'full' || !isSubUser;

  // 🎯 دالة جديدة لتحميل البيانات من الذاكرة الدائمة للذاكرة الحية
  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('loggedUser');
    
    if (userData != null) {
      final Map<String, dynamic> data = json.decode(userData);
      userId = data['id'];
      ownerId = data['ownerId'];
      role = data['role'];
      phoneNumber = data['phone'];
      merchantName = data['merchantName'];
      isSubUser = data['isSubUser'] ?? false;
    }
  }

  // 🎯 دالة لتحديث البيانات يدوياً عند الحاجة
  static void updateFromMap(Map<String, dynamic> data) {
    userId = data['id'];
    ownerId = data['ownerId'];
    role = data['role'];
    phoneNumber = data['phone'];
    merchantName = data['merchantName'];
    isSubUser = data['isSubUser'] ?? false;
  }

  static void clear() {
    userId = null;
    ownerId = null;
    role = null;
    phoneNumber = null;
    merchantName = null;
    isSubUser = false;
  }
}

