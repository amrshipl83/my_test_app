// lib/screens/seller/seller_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sizer/sizer.dart';

const Color primaryColor = Color(0xff28a745);
// 🎯 تم توحيد الإعدادات مع صفحة التسجيل لضمان النجاح
const String CLOUDINARY_URL = "https://api.cloudinary.com/v1_1/dgmmx6jbu/image/upload";
const String UPLOAD_PRESET = "commerce"; 

class SellerSettingsScreen extends StatefulWidget {
  final String currentSellerId;
  const SellerSettingsScreen({super.key, required this.currentSellerId});

  @override
  State<SellerSettingsScreen> createState() => _SellerSettingsScreenState();
}

class _SellerSettingsScreenState extends State<SellerSettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  bool _isUploading = false;

  Map<String, dynamic> sellerDataCache = {};
  List<Map<String, dynamic>> subUsersList = [];

  final _merchantNameController = TextEditingController();
  final _minOrderTotalController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _subUserPhoneController = TextEditingController();
  String _selectedSubUserRole = 'read_only';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadSellerData();
    await _loadSubUsersFromCollection();
    setState(() => _isLoading = false);
  }

  Future<void> _loadSellerData() async {
    try {
      final doc = await _firestore.collection("sellers").doc(widget.currentSellerId).get();
      if (doc.exists) {
        sellerDataCache = doc.data()!;
        setState(() {
          // 🎯 جلب البيانات باستخدام المفاتيح الصحيحة من الفايربيز
          _merchantNameController.text = sellerDataCache['merchantName'] ?? '';
          _minOrderTotalController.text = (sellerDataCache['minOrderTotal'] ?? 0).toString();
          _deliveryFeeController.text = (sellerDataCache['deliveryFee'] ?? 0).toString();
        });
      }
    } catch (e) {
      debugPrint("Error loading seller data: $e");
    }
  }

  Future<void> _loadSubUsersFromCollection() async {
    try {
      final snapshot = await _firestore
          .collection("subUsers")
          .where("parentSellerId", isEqualTo: widget.currentSellerId)
          .get();
      subUsersList = snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("Error loading sub-users: $e");
    }
  }

  Future<void> _updateSettings() async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection("sellers").doc(widget.currentSellerId).update({
        'merchantName': _merchantNameController.text.trim(),
        'minOrderTotal': double.tryParse(_minOrderTotalController.text) ?? 0.0,
        'deliveryFee': double.tryParse(_deliveryFeeController.text) ?? 0.0,
      });
      _showFloatingAlert("✅ تم تحديث الإعدادات بنجاح");
    } catch (e) {
      _showFloatingAlert("❌ فشل التحديث: تأكد من الاتصال", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

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
      if (res.statusCode == 200) {
        var responseData = await res.stream.bytesToString();
        var jsonRes = json.decode(responseData);
        String newUrl = jsonRes['secure_url'];

        // 🎯 تحديث المفتاح الصحيح logoUrl
        await _firestore.collection("sellers").doc(widget.currentSellerId).update({
          'logoUrl': newUrl
        });
        await _refreshData();
        _showFloatingAlert("✅ تم تحديث الشعار بنجاح");
      }
    } catch (e) {
      _showFloatingAlert("❌ حدث خطأ أثناء الرفع", isError: true);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          title: Text('إعدادات الحساب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp)),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                child: Column(
                  children: [
                    _buildLogoHeader(),
                    SizedBox(height: 4.h),
                    _buildSectionTitle("بيانات النشاط"),
                    
                    // حقول قابلة للتعديل
                    _buildModernField("اسم النشاط", _merchantNameController, Icons.storefront, isReadOnly: false),
                    
                    // حقول قراءة فقط (ثابتة)
                    _buildReadOnlyField("نوع النشاط", sellerDataCache['businessType'] ?? 'غير محدد', Icons.category),
                    _buildReadOnlyField("رقم الهاتف المسجل", sellerDataCache['phone'] ?? '', Icons.phone_android),
                    _buildReadOnlyField("العنوان الحالي", sellerDataCache['address'] ?? '', Icons.location_on),

                    _buildSectionTitle("إعدادات البيع والتوصيل"),
                    Row(
                      children: [
                        Expanded(child: _buildModernField("الحد الأدنى", _minOrderTotalController, Icons.shopping_basket, isNum: true)),
                        SizedBox(width: 3.w),
                        Expanded(child: _buildModernField("رسوم التوصيل", _deliveryFeeController, Icons.local_shipping, isNum: true)),
                      ],
                    ),
                    
                    SizedBox(height: 2.h),
                    _buildMainButton("حفظ التعديلات", Icons.save, _updateSettings),
                    
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 3.h),
                      child: const Divider(color: Color(0xfff1f1f1), thickness: 2),
                    ),
                    
                    _buildSectionTitle("إضافة موظف (Sub-User)"),
                    _buildModernField("رقم هاتف الموظف", _subUserPhoneController, Icons.person_add_alt_1, isNum: true),
                    _buildRoleDropdown(),
                    _buildMainButton("إضافة الموظف الآن", Icons.add_moderator, _addSubUser, color: Colors.blueGrey[800]!),
                    
                    SizedBox(height: 3.h),
                    _buildSubUsersList(),
                    SizedBox(height: 5.h),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLogoHeader() {
    // 🎯 استخدام logoUrl ليطابق الداتابيز
    String? logo = sellerDataCache['logoUrl'];
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: primaryColor.withOpacity(0.2), width: 4),
          ),
          child: CircleAvatar(
            radius: 65,
            backgroundColor: const Color(0xfff8f9fa),
            backgroundImage: logo != null ? NetworkImage(logo) : null,
            child: logo == null ? Icon(Icons.store, size: 50, color: Colors.grey[400]) : null,
          ),
        ),
        CircleAvatar(
          backgroundColor: primaryColor,
          radius: 20,
          child: _isUploading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                  onPressed: _uploadLogo,
                ),
        )
      ],
    );
  }

  // --- دوال الموظفين (Sub-Users) كما هي مع تحسين الشكل ---
  Future<void> _addSubUser() async {
    final phone = _subUserPhoneController.text.trim();
    if (phone.isEmpty) {
      _showFloatingAlert("⚠️ يرجى إدخال رقم الهاتف", isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      String fakeEmail = "$phone@aksab.com"; // توحيد النطاق مع النظام الذكي
      try { await _auth.createUserWithEmailAndPassword(email: fakeEmail, password: "123456"); } catch (_) {}
      
      final subData = {
        'phone': phone,
        'role': _selectedSubUserRole,
        'parentSellerId': widget.currentSellerId,
        'mustChangePassword': true,
        'addedAt': FieldValue.serverTimestamp(),
        'merchantName': sellerDataCache['merchantName'] ?? 'متجر',
      };
      await _firestore.collection("subUsers").doc(phone).set(subData, SetOptions(merge: true));
      _subUserPhoneController.clear();
      await _refreshData();
      _showFloatingAlert("✅ تمت إضافة الموظف.\nكلمة المرور الافتراضية: 123456");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeSubUser(String phone) async {
    try {
      await _firestore.collection("subUsers").doc(phone).delete();
      await _refreshData();
      _showFloatingAlert("🗑️ تم الحذف بنجاح");
    } catch (e) {
      _showFloatingAlert("❌ خطأ أثناء الحذف", isError: true);
    }
  }

  // --- عناصر الواجهة المحسنة ---

  Widget _buildModernField(String label, TextEditingController ctrl, IconData icon, {bool isNum = false, bool isReadOnly = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: TextField(
        controller: ctrl,
        readOnly: isReadOnly,
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: isReadOnly ? Colors.grey : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: isReadOnly ? Colors.grey : primaryColor, size: 20),
          filled: true,
          fillColor: isReadOnly ? const Color(0xfff1f3f5) : const Color(0xfff8f9fa),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return _buildModernField(label, TextEditingController(text: value), icon, isReadOnly: true);
  }

  Widget _buildRoleDropdown() {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      decoration: BoxDecoration(color: const Color(0xfff8f9fa), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xffe9ecef))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSubUserRole,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'full', child: Text('مدير حساب (صلاحية كاملة)')),
            DropdownMenuItem(value: 'read_only', child: Text('موظف (عرض فقط)')),
          ],
          onChanged: (v) => setState(() => _selectedSubUserRole = v!),
        ),
      ),
    );
  }

  Widget _buildSubUsersList() {
    return Column(
      children: subUsersList.map((u) => Card(
        margin: EdgeInsets.only(bottom: 1.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.person, color: Colors.white)),
          title: Text(u['phone'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(u['role'] == 'full' ? 'صلاحية كاملة' : 'عرض فقط'),
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeSubUser(u['phone'])),
        ),
      )).toList(),
    );
  }

  Widget _buildMainButton(String label, IconData icon, VoidCallback onPressed, {Color color = primaryColor}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(label, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(backgroundColor: color, minimumSize: Size(double.infinity, 6.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(alignment: Alignment.centerRight, child: Padding(padding: EdgeInsets.symmetric(vertical: 1.5.h), child: Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: Colors.black87))));
  }

  void _showFloatingAlert(String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isError ? Icons.error : Icons.check_circle, color: isError ? Colors.red : primaryColor, size: 40.sp),
            SizedBox(height: 2.h),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 2.h),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً"))
          ],
        ),
      ),
    );
  }
}

