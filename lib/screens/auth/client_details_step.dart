// lib/screens/auth/client_details_step.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:sizer/sizer.dart';
import 'package:permission_handler/permission_handler.dart';

class ClientDetailsStep extends StatefulWidget {
  final Map<String, TextEditingController> controllers;
  final String selectedUserType;
  final bool isSaving;
  final ValueChanged<String?> onBusinessTypeChanged;
  final Function({required double lat, required double lng}) onLocationChanged;
  final Function({required String field, required File file}) onFilePicked;
  final VoidCallback onRegister;
  final VoidCallback onGoBack;

  const ClientDetailsStep({
    super.key,
    required this.controllers,
    required this.selectedUserType,
    required this.isSaving,
    required this.onBusinessTypeChanged,
    required this.onLocationChanged,
    required this.onFilePicked,
    required this.onRegister,
    required this.onGoBack,
  });

  @override
  State<ClientDetailsStep> createState() => _ClientDetailsStepState();
}

class _ClientDetailsStepState extends State<ClientDetailsStep> {
  final _formKey = GlobalKey<FormState>();
  late MapController _mapController;
  LatLng _initialPosition = const LatLng(30.0444, 31.2357);

  File? _logoPreview, _crPreview, _tcPreview;
  bool _termsAgreed = false;
  bool _isMapActive = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    widget.onLocationChanged(lat: _initialPosition.latitude, lng: _initialPosition.longitude);
  }

  // دالة عرض سياسة الخصوصية (BottomSheet)
  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 80.h,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            SizedBox(height: 20),
            Text('سياسة الخصوصية والشروط', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: const Color(0xFF2D9E68))),
            const Divider(height: 30),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  "مرحباً بك في منصة أكسب.\n\n"
                  "1. البيانات التي نجمعها: نقوم بجمع رقم هاتفك ليكون معرفاً لحسابك، وموقعك الجغرافي لتسهيل وصول المندوبين إليك.\n\n"
                  "2. الاستخدام: بياناتك مشفرة ولا يتم مشاركتها مع أطراف ثالثة خارج نطاق تنفيذ الطلبات.\n\n"
                  "3. مسؤولية المحتوى: الموردين والمشترين مسؤولين عن دقة البيانات المرفوعة من قبلهم.\n\n"
                  "بالموافقة على هذه الشروط، أنت تقر بصحة البيانات المدخلة.",
                  style: TextStyle(fontSize: 13.sp, height: 1.6, color: Colors.black87),
                ),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D9E68), padding: const EdgeInsets.all(15)),
                onPressed: () => Navigator.pop(context),
                child: const Text('فهمت وأوافق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAddress(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        widget.controllers['address']!.text = "${place.street ?? ''}, ${place.locality ?? ''}";
      }
      widget.onLocationChanged(lat: position.latitude, lng: position.longitude);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (await Permission.location.request().isGranted) {
      Position position = await Geolocator.getCurrentPosition();
      final newPos = LatLng(position.latitude, position.longitude);
      _mapController.move(newPos, 15);
      setState(() {
        _initialPosition = newPos;
        _isMapActive = true;
      });
      _updateAddress(newPos);
    }
  }

  Future<void> _pickFile(String field) async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      widget.onFilePicked(field: field, file: file);
      setState(() {
        if (field == 'logo') _logoPreview = file;
        if (field == 'cr') _crPreview = file;
        if (field == 'tc') _tcPreview = file;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إكمال بيانات الحساب',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2D9E68),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              _buildSectionHeader('المعلومات الأساسية', Icons.badge_rounded),
              _buildInputField('fullname', 'الاسم الكامل', Icons.person_rounded),
              _buildInputField('phone', 'رقم الهاتف (سيكون هو اسم المستخدم)', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
              _buildSectionHeader('العنوان والموقع', Icons.map_rounded),
              _buildInputField('address', 'العنوان الحالي (يحدد من الخريطة)', Icons.location_on_rounded, readOnly: true),
              _buildMapContainer(),
              _buildSectionHeader('الأمان', Icons.security_rounded),
              _buildInputField('password', 'كلمة المرور', Icons.lock_open_rounded, isPassword: true),
              _buildInputField('confirmPassword', 'تأكيد كلمة المرور', Icons.lock_rounded, isPassword: true),
              if (widget.selectedUserType == 'seller') ...[
                SizedBox(height: 3.h),
                _buildSellerDetailsCard(),
              ],
              SizedBox(height: 3.h),
              _buildTermsCheckbox(), // تم تحديثه ليشمل رابط السياسة
              SizedBox(height: 4.h),
              _buildSubmitButton(),
              SizedBox(height: 3.h),
              TextButton(
                onPressed: widget.onGoBack,
                child: Text('العودة لتعديل نوع الحساب',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13.sp, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.5.h, top: 1.5.h),
      child: Row(
        children: [
          Icon(icon, size: 28, color: const Color(0xFF2D9E68)),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: const Color(0xFF1A1A1A))),
          const Expanded(child: Divider(indent: 20, thickness: 1.5, color: Color(0xFFE8E8E8))),
        ],
      ),
    );
  }

  Widget _buildInputField(String key, String label, IconData icon, {bool isPassword = false, bool readOnly = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.5.h),
      child: TextFormField(
        controller: widget.controllers[key],
        obscureText: isPassword && _obscurePassword,
        readOnly: readOnly,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          contentPadding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          suffixIcon: Icon(icon, color: const Color(0xFF2D9E68).withOpacity(0.7), size: 28),
          prefixIcon: isPassword
              ? IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 25, color: Colors.grey),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          filled: true,
          fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF2D9E68), width: 2)),
        ),
      ),
    );
  }

  Widget _buildMapContainer() {
    return Container(
      height: 35.h,
      margin: EdgeInsets.only(bottom: 3.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialPosition, 
                initialZoom: 14.0,
                onTap: (tapPosition, point) {
                   setState(() { _initialPosition = point; _isMapActive = true; });
                   _updateAddress(point);
                }
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                MarkerLayer(markers: [
                  Marker(width: 50, height: 50, point: _initialPosition, child: const Icon(Icons.location_pin, size: 45, color: Colors.red)),
                ]),
              ],
            ),
            if (!_isMapActive)
              Container(
                color: Colors.white.withOpacity(0.8),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _goToCurrentLocation,
                    icon: const Icon(Icons.my_location, size: 22, color: Colors.white),
                    label: const Text('تحديد موقعي الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D9E68), padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerDetailsCard() {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F3),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: const Color(0xFF2D9E68).withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Text('بيانات الموردين', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: const Color(0xFF2D9E68))),
          SizedBox(height: 3.h),
          _buildInputField('merchantName', 'اسم الشركة / النشاط', Icons.business_rounded),
          _buildUploadItem('شعار المورد', 'logo', _logoPreview),
          _buildUploadItem('السجل التجاري', 'cr', _crPreview),
          _buildUploadItem('البطاقة الضريبية', 'tc', _tcPreview),
        ],
      ),
    );
  }

  Widget _buildUploadItem(String label, String field, File? file) {
    return GestureDetector(
      onTap: () => _pickFile(field),
      child: Container(
        margin: EdgeInsets.only(bottom: 2.h),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: file != null ? Colors.green : Colors.grey.shade300, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(file != null ? Icons.check_circle : Icons.cloud_upload_outlined, size: 30, color: file != null ? Colors.green : Colors.grey),
            const SizedBox(width: 15),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black87))),
            if (file != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(file, width: 50, height: 50, fit: BoxFit.cover)),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        children: [
          Checkbox(
            value: _termsAgreed,
            onChanged: (v) => setState(() => _termsAgreed = v!),
            activeColor: const Color(0xFF2D9E68),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(
            child: InkWell(
              onTap: _showPrivacyPolicy, // يفتح السياسة عند الضغط
              child: Text.rich(
                TextSpan(
                  text: 'أوافق على ',
                  style: TextStyle(fontSize: 12.sp, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: 'شروط الاستخدام وسياسة الخصوصية',
                      style: TextStyle(
                        color: const Color(0xFF2D9E68),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D9E68).withOpacity(_termsAgreed ? 0.3 : 0),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: (widget.isSaving || !_termsAgreed) ? null : widget.onRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D9E68),
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          elevation: 0,
        ),
        child: widget.isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Text('إتمام التسجيل والبدء', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    );
  }
}

