// lib/screens/consumer/abaatly_had_pro_screen.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart'; // استيراد الشريط السفلي
import 'location_picker_screen.dart';

class AbaatlyHadProScreen extends StatefulWidget {
  static const routeName = '/abaatly-had';
  final LatLng userCurrentLocation;
  final bool isStoreOwner;

  const AbaatlyHadProScreen({
    super.key,
    required this.userCurrentLocation,
    this.isStoreOwner = false,
  });

  @override
  State<AbaatlyHadProScreen> createState() => _AbaatlyHadProScreenState();
}

class _AbaatlyHadProScreenState extends State<AbaatlyHadProScreen> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  LatLng? _pickupCoords;
  LatLng? _dropoffCoords;
  bool _pickupConfirmed = false;
  bool _dropoffConfirmed = false;
  late LatLng _liveLocation;

  @override
  void initState() {
    super.initState();
    _liveLocation = widget.userCurrentLocation;
    _checkPermissionAndGetLocation();
  }

  Future<void> _checkPermissionAndGetLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _liveLocation = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _pickLocation(bool isPickup) async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: _liveLocation, 
          title: isPickup ? "حدد مكان الاستلام" : "حدد مكان التسليم",
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isPickup) {
          _pickupCoords = result;
          _pickupController.text = "تم تحديد مكان الاستلام ✅";
          _pickupConfirmed = true;
        } else {
          _dropoffCoords = result;
          _dropoffController.text = "تم تحديد وجهة التسليم ✅";
          _dropoffConfirmed = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        appBar: AppBar(
          title: Text("إعداد مسار التوصيل", 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp, color: Colors.black)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 25), 
            onPressed: () => Navigator.pop(context)
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // كارت الاستلام
              _buildLocationCard(
                label: "من أين سيستلم المندوب؟",
                controller: _pickupController,
                icon: Icons.location_on,
                color: const Color(0xFF43A047),
                isConfirmed: _pickupConfirmed,
                onTap: () => _pickLocation(true),
              ),
              
              // سهم الربط بتصميم أنيق
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Icon(Icons.south_rounded, color: Colors.grey[300], size: 40),
                ),
              ),

              // كارت التسليم
              _buildLocationCard(
                label: "أين سيتم تسليم الشحنة؟",
                controller: _dropoffController,
                icon: Icons.flag_rounded,
                color: const Color(0xFFE53935),
                isConfirmed: _dropoffConfirmed,
                onTap: () => _pickLocation(false),
              ),

              const SizedBox(height: 35),
              
              // قسم الشروط بتنسيق أوضح
              _buildTermsSection(),
              
              const SizedBox(height: 30),
              
              // زر التأكيد يظهر فقط عند اكتمال البيانات
              if (_pickupConfirmed && _dropoffConfirmed)
                _buildConfirmButton(),
              
              const SizedBox(height: 50), // مساحة إضافية للسكرول
            ],
          ),
        ),
        // ✨ إضافة الشريط السفلي لضمان تتبع أي طلبات أخرى قائمة
        bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: -1),
      ),
    );
  }

  Widget _buildLocationCard({
    required String label, 
    required TextEditingController controller, 
    required IconData icon, 
    required Color color, 
    required bool isConfirmed, 
    required VoidCallback onTap
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isConfirmed ? color.withOpacity(0.5) : Colors.transparent, 
              width: 2
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04), 
                blurRadius: 20, 
                offset: const Offset(0, 10)
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11.sp, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(
                      controller.text.isEmpty ? "اضغط للتحديد من الخريطة" : controller.text, 
                      style: TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: 13.sp, 
                        color: isConfirmed ? Colors.black : Colors.orange[800]
                      )
                    ),
                  ],
                ),
              ),
              Icon(
                isConfirmed ? Icons.check_circle_rounded : Icons.add_location_alt_outlined, 
                color: isConfirmed ? Colors.green : Colors.grey[300], 
                size: 28
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_rounded, color: Colors.amber, size: 24),
              const SizedBox(width: 10),
              Text("شروط الاستخدام والضمان", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp)),
            ],
          ),
          const Divider(height: 30),
          _buildTermItem("المسؤولية القانونية عن المحتوى تقع على طرفي العملية."),
          _buildTermItem("يُمنع نقل الأموال أو المواد المحظورة قانوناً."),
          _buildTermItem("كود التسليم هو توقيعك؛ لا تعطه للمندوب إلا بعد الفحص."),
          _buildTermItem("طابق هوية المندوب وصورته من التطبيق قبل التسليم."),
        ],
      ),
    );
  }

  Widget _buildTermItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 8, color: Colors.amber[700]).paddingOnly(top: 8),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.3))),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF2E7D32)]),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton(
        onPressed: () {
          // هنا يتم الانتقال لصفحة تأكيد الطلب أو الدفع
        }, 
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, 
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
        ), 
        child: Text("تأكيد المسار والمتابعة", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp, color: Colors.white))
      ),
    );
  }
}

// إضافة بسيطة لتسهيل الـ Padding في الـ TermItem
extension OnWidget on Widget {
  Widget paddingOnly({double top = 0}) => Padding(padding: EdgeInsets.only(top: top), child: this);
}
