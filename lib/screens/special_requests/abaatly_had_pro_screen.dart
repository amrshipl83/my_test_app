// lib/screens/special_requests/abaatly_had_pro_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart'; // تأكد من استيراد sizer للتحكم في الأحجام
import 'location_picker_screen.dart';

class AbaatlyHadProScreen extends StatefulWidget {
  final LatLng userCurrentLocation;
  final bool isStoreOwner;

  const AbaatlyHadProScreen({
    super.key,
    required this.userCurrentLocation,
    this.isStoreOwner = false
  });

  @override
  State<AbaatlyHadProScreen> createState() => _AbaatlyHadProScreenState();
}

class _AbaatlyHadProScreenState extends State<AbaatlyHadProScreen> {
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  LatLng? _pickupCoords;
  LatLng? _dropoffCoords;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupInitialLocations();
  }

  void _setupInitialLocations() {
    if (widget.isStoreOwner) {
      _pickupController.text = "موقعي الحالي (المحل)";
      _pickupCoords = widget.userCurrentLocation;
    } else {
      _dropoffController.text = "موقعي الحالي (المنزل)";
      _dropoffCoords = widget.userCurrentLocation;
    }
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
          _pickupController.text = "تم التحديد من الخريطة ✅";
        } else {
          _dropoffCoords = result;
          _dropoffController.text = "تم التحديد من الخريطة ✅";
        }
      });
    }
  }

  Future<void> _submitOrder() async {
    if (_detailsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى كتابة تفاصيل الطلب")));
      return;
    }

    if (_pickupCoords == null || _dropoffCoords == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى تحديد النقطتين من الخريطة")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('specialRequests').add({
        'details': _detailsController.text,
        'pickupAddress': _pickupController.text,
        'dropoffAddress': _dropoffController.text,
        'pickupLocation': GeoPoint(_pickupCoords!.latitude, _pickupCoords!.longitude),
        'dropoffLocation': GeoPoint(_dropoffCoords!.latitude, _dropoffCoords!.longitude),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'requestType': widget.isStoreOwner ? 'store_delivery' : 'consumer_personal',
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إرسال طلبك للمناديب 🚀")));
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text("ابعتلي حد (توصيل خاص)", 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.black87)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              _buildLocationInput(
                label: "منين؟ (مكان الاستلام)",
                controller: _pickupController,
                icon: Icons.location_on,
                color: Colors.green[700]!,
                onTap: () => _pickLocation(true),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Icon(Icons.arrow_downward_rounded, color: Colors.orange[800], size: 35),
              ),
              _buildLocationInput(
                label: "لفين؟ (مكان التسليم)",
                controller: _dropoffController,
                icon: Icons.flag_rounded,
                color: Colors.red[700]!,
                onTap: () => _pickLocation(false),
              ),
              const SizedBox(height: 30),
              
              // تحسين شكل حقل التفاصيل ليكون أوضح
              Text("ماذا تريد أن تنقل؟", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.black87)),
              const SizedBox(height: 10),
              TextField(
                controller: _detailsController,
                maxLines: 4,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "مثال: كرتونة طلبات، طقم انتريه...",
                  hintStyle: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.normal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.grey[200]!, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[900],
                  minimumSize: const Size(double.infinity, 70),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 8,
                ),
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("تأكيد وطلب مندوب الآن", 
                      style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey[200]!, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 11.sp, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    controller.text.isEmpty ? "اضغط للتحديد من الخريطة" : controller.text,
                    style: TextStyle(
                      fontWeight: FontWeight.w900, // خط عريض جداً للعنوان
                      fontSize: 13.sp, 
                      color: controller.text.isEmpty ? Colors.blueGrey : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.map_outlined, color: Colors.blue[800], size: 22.sp),
          ],
        ),
      ),
    );
  }
}
