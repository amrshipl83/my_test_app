import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
import 'location_picker_screen.dart';

class AbaatlyHadProScreen extends StatefulWidget {
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
  // تم الاحتفاظ بالكونترولر لإدارة النصوص الظاهرة فقط
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  LatLng? _pickupCoords;
  LatLng? _dropoffCoords;
  bool _pickupConfirmed = false;
  bool _dropoffConfirmed = false;

  @override
  void initState() {
    super.initState();
    // إفراغ الحقول تماماً لضمان تسلسل الاختيار اليدوي من الخريطة
    _pickupController.clear();
    _dropoffController.clear();
  }

  Future<void> _pickLocation(bool isPickup) async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: widget.userCurrentLocation,
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
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black, size: 30), 
            onPressed: () => Navigator.pop(context)
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildLocationCard(
                label: "من أين سيستلم المندوب؟",
                controller: _pickupController,
                icon: Icons.location_on,
                color: Colors.green[700]!,
                isConfirmed: _pickupConfirmed,
                onTap: () => _pickLocation(true),
              ),
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Icon(Icons.keyboard_double_arrow_down_rounded, color: Colors.grey, size: 45),
              )),
              _buildLocationCard(
                label: "أين سيتم تسليم الشحنة؟",
                controller: _dropoffController,
                icon: Icons.flag_rounded,
                color: Colors.red[700]!,
                isConfirmed: _dropoffConfirmed,
                onTap: () => _pickLocation(false),
              ),
              
              const SizedBox(height: 40),
              
              _buildTermsSection(),
              
              const SizedBox(height: 40),
              
              // زر المتابعة يظهر فقط عند اكتمال تحديد النقطتين
              if (_pickupConfirmed && _dropoffConfirmed)
                _buildConfirmButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsSection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.amber.withOpacity(0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.amber, size: 28),
              const SizedBox(width: 12),
              Text("شروط الاستخدام والضمان", 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 20),
          _buildTermItem("المنصة وسيط تقني؛ المسؤولية القانونية عن محتوى الشحنة تقع بالكامل على طرفي العملية."),
          _buildTermItem("يُمنع منعاً باتاً نقل الأموال، المشغولات الذهبية، أو المواد المحظورة قانوناً."),
          // 👈 البند الجديد الذي طلبته بصيغة قوية
          _buildTermItem("كود التسليم (Delivery Code) هو توقيعك الإلكتروني بالاستلام؛ لا تعطه للمندوب إلا بعد فحص الشحنة والتأكد من سلامتها تماماً."),
          _buildTermItem("يجب مطابقة هوية المندوب وصورته من التطبيق قبل تسليمه أي أغراض."),
        ],
      ),
    );
  }

  Widget _buildTermItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6), 
            child: Icon(Icons.check_circle_outline, size: 18, color: Colors.amber[900]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text, 
              style: TextStyle(
                fontSize: 13.sp, // 👈 تكبير الخط كما طلبت (كان 12.5)
                fontWeight: FontWeight.w700, 
                color: Colors.black, 
                height: 1.4
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
    required bool isConfirmed,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: isConfirmed ? color : Colors.grey[300]!, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withOpacity(0.1), 
              child: Icon(icon, color: color, size: 30)
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11.sp, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    controller.text.isEmpty ? "اضغط للتحديد من الخريطة" : controller.text,
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 14.sp, 
                      color: isConfirmed ? Colors.black : Colors.red[800]
                    )
                  ),
                ],
              ),
            ),
            Icon(
              isConfirmed ? Icons.verified : Icons.add_location_alt_outlined, 
              color: isConfirmed ? Colors.green : Colors.grey[400], 
              size: 30
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: () {
          // هنا يتم الانتقال لصفحة كتابة تفاصيل الحمولة النهائية والطلب
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 5,
        ),
        child: Text("تأكيد المسار والمتابعة", 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.white)),
      ),
    );
  }
}
