// lib/data_sources/client_data_source.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';

class ClientDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // 🟢 الدالة المفقودة التي يطلبها الـ Build
  Future<User?> registerClient({
    required String fullname,
    required String email,
    required String password,
    required String address,
    required String country,
    required String userType,
    Map<String, double>? location,
    File? logo,
    String? merchantName,
    String? businessType,
    String? additionalPhone,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      final String userId = userCredential.user!.uid;

      final Map<String, dynamic> userData = {
        'fullname': fullname,
        'email': email,
        'address': address,
        'location': location,
        'role': userType,
        'country': country,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (userType == 'seller') {
        userData['merchantName'] = merchantName;
        userData['businessType'] = businessType;
        userData['additionalPhone'] = additionalPhone;
        userData['isVerified'] = false;
      } else {
        userData['isVerified'] = true;
      }

      String targetCollectionName;
      if (userType == "seller") {
        targetCollectionName = "pendingSellers";
      } else if (userType == "consumer") {
        targetCollectionName = "consumers";
      } else {
        targetCollectionName = "users";
      }

      await _firestore.collection(targetCollectionName).doc(userId).set(userData);
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
        body: json.encode({'userId': userId, 'fcmToken': fcmToken, 'role': role, 'address': address}),
      );
    } catch (e) {}
  }
}
