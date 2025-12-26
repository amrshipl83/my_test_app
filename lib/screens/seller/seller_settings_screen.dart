// lib/screens/seller/seller_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- الثوابت ---
const Color primaryColor = Color(0xff28a745);
const String CLOUDINARY_URL = "https://api.cloudinary.com/v1_1/dcl96v8p6/image/upload";
const String UPLOAD_PRESET = "aksab_presets";

class SellerSettingsScreen extends StatefulWidget {
  final String currentSellerId;
  const SellerSettingsScreen({super.key, required this.currentSellerId});

  @override
  State<SellerSettingsScreen> createState() => _SellerSettingsScreenState();
}

class _SellerSettingsScreenState extends State<SellerSettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isUploading = false;

  Map<String, dynamic> sellerDataCache = {};
  final _merchantNameController = TextEditingController();
  final _minOrderTotalController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _subUserPhoneController = TextEditingController();

  String? _selectedBusinessType;
  String _selectedSubUserRole = 'full';

  @override
  void initState() {
    super.initState();
    _loadSellerData();
  }

  Future<void> _loadSellerData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection("sellers").doc(widget.currentSellerId).get();
      if (doc.exists) {
        sellerDataCache = doc.data()!;
        _merchantNameController.text = sellerDataCache['merchantName'] ?? '';
        _minOrderTotalController.text = (sellerDataCache['minOrderTotal'] ?? 0.0).toString();
        _deliveryFeeController.text = (sellerDataCache['deliveryFee'] ?? 0.0).toString();
        _selectedBusinessType = sellerDataCache['businessType'];
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 1. رفع الشعار لـ Cloudinary
  Future<void> _uploadLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse(CLOUDINARY_URL));
      request.fields['upload_preset'] = UPLOAD_PRESET;
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var res = await request.send();
      var responseData = await res.stream.bytesToString();
      var jsonRes = json.decode(responseData);

      if (res.statusCode == 200) {
        await _firestore.collection("sellers").doc(widget.currentSellerId).update({
          'merchantLogoUrl': jsonRes['secure_url']
        });
        _loadSellerData();
        _showSnackBar("✅ تم تحديث الشعار");
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // 2. إضافة موظف مع باسورد افتراضي "123456"
  Future<void> _addSubUser() async {
    final phone = _subUserPhoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final newSub = {
        'phone': phone,
        'role': _selectedSubUserRole,
        'mustChangePassword': true, // إجبار على التغيير
        'addedAt': DateTime.now().toIso8601String(),
      };
      
      await _firestore.collection("sellers").doc(widget.currentSellerId).update({
        'subUsers': FieldValue.arrayUnion([newSub])
      });
      
      _subUserPhoneController.clear();
      _loadSellerData();
      _showSnackBar("✅ تمت إضافة الموظف. الباسورد الافتراضي: 123456");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إعدادات الحساب'), backgroundColor: primaryColor),
        body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // قسم الشعار
              _buildLogoHeader(),
              const Divider(),
              
              _buildSectionTitle("بيانات العمل"),
              _buildTextField("اسم النشاط", _merchantNameController),
              _buildTextField("الحد الأدنى للطلب", _minOrderTotalController, isNum: true),
              _buildTextField("مصاريف الشحن", _deliveryFeeController, isNum: true),
              
              ElevatedButton(
                onPressed: _updateSettings,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, minimumSize: const Size(double.infinity, 50)),
                child: const Text("حفظ الإعدادات", style: TextStyle(color: Colors.white)),
              ),

              const SizedBox(height: 30),
              _buildSectionTitle("الموظفين (الصلاحيات)"),
              _buildTextField("رقم هاتف الموظف", _subUserPhoneController, isNum: true),
              DropdownButtonFormField<String>(
                value: _selectedSubUserRole,
                items: const [
                  DropdownMenuItem(value: 'full', child: Text('صلاحية كاملة')),
                  DropdownMenuItem(value: 'read_only', child: Text('عرض فقط')),
                ],
                onChanged: (v) => setState(() => _selectedSubUserRole = v!),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _addSubUser,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, minimumSize: const Size(double.infinity, 45)),
                child: const Text("إضافة موظف", style: TextStyle(color: Colors.white)),
              ),
              
              // عرض القائمة
              const SizedBox(height: 20),
              ...(sellerDataCache['subUsers'] as List? ?? []).map((u) => ListTile(
                leading: const Icon(Icons.person),
                title: Text(u['phone']),
                subtitle: Text(u['role'] == 'full' ? 'صلاحية كاملة' : 'عرض فقط'),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeSubUser(u)),
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  // --- دوال مساعدة للواجهة ---
  Widget _buildLogoHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[200],
          backgroundImage: sellerDataCache['merchantLogoUrl'] != null ? NetworkImage(sellerDataCache['merchantLogoUrl']) : null,
          child: sellerDataCache['merchantLogoUrl'] == null ? const Icon(Icons.store, size: 40) : null,
        ),
        TextButton.icon(
          onPressed: _isUploading ? null : _uploadLogo,
          icon: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt),
          label: const Text("تغيير شعار المتجر"),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))));
  }

  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  
  // دالات الحفظ والحذف (بسيطة)
  Future<void> _updateSettings() async { /* تحديث Firestore */ }
  Future<void> _removeSubUser(Map u) async { /* FieldValue.arrayRemove */ }
}

