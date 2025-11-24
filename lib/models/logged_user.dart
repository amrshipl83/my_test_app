// lib/models/logged_user.dart
import 'dart:convert';

class LoggedInUser {
  final String id;
  final String fullname;
  final String role; 
  // يمكنك إضافة أي حقول أخرى تم تخزينها في auth_service.dart مثل address, merchantName, location

  LoggedInUser({required this.id, required this.fullname, required this.role});

  factory LoggedInUser.fromJson(Map<String, dynamic> json) {
    return LoggedInUser(
      id: json['id'] as String,
      fullname: json['fullname'] as String,
      role: json['role'] as String,
    );
  }
}
