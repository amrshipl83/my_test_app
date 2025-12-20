// lib/screens/special_requests/location_picker_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/screens/consumer/consumer_home_screen.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  final String title;
  final String userId;

  const LocationPickerScreen({
    super.key,
    required this.initialLocation,
    required this.title,
    required this.userId,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _draggedLocation;
  String _address = "جاري جلب العنوان...";
  final MapController _mapController = MapController();
  bool _isAgreed = false; // حالة الموافقة على الشروط

  @override
  void initState() {
    super.initState();
    _draggedLocation = widget.initialLocation;
    _reverseGeocode(_draggedLocation);
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address = "${place.street}, ${place.subLocality}";
        });
      }
    } catch (e) {
      setState(() => _address = "موقع غير محدد بدقة");
    }
  }

  // نافذة تأكيد الطلب مع الموافقة القانونية (Explicit Consent)
  void _showConfirmationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(25),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Icon(Icons.verified_user_rounded, color: Colors.blue, size: 40),
              const SizedBox(height: 10),
              const Text("تأكيد طلب 'ابعتلي حد'", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(height: 30),
              
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text("سيتم الاستلام من: $_address", style: const TextStyle(fontSize: 14))),
                ],
              ),
              const SizedBox(height: 15),

              // مربع الموافقة الصريحة
              CheckboxListTile(
                value: _isAgreed,
                activeColor: Colors.blue,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  "أتعهد بعدم نقل مواد مخالفة للقانون، سوائل قابلة للاشتعال، أو مستندات حساسة، وأقر بأن التطبيق وسيط تقني فقط.",
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                ),
                onChanged: (val) => setSheetState(() => _isAgreed = val!),
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAgreed ? _finalizeRequest : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: const Text("تأكيد وإرسال الطلب الآن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // دالة الحفظ الفعلي في Firestore
  Future<void> _finalizeRequest() async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

      await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': widget.userId,
        'address': _address,
        'location': GeoPoint(_draggedLocation.latitude, _draggedLocation.longitude),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'agreedToTerms': true,
      });

      Navigator.pop(context); // إغلاق الـ Loading
      Navigator.pop(context); // إغلاق الـ BottomSheet
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم إرسال طلبك بنجاح! سيتم التواصل معك قريباً."), backgroundColor: Colors.green),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في الإرسال: $e")));
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("الشروط القانونية", textAlign: TextAlign.center),
        content: const Text(
          "1. التطبيق وسيط تقني يربط العميل بمقدم الخدمة.\n"
          "2. يمنع نقل الأموال، المجوهرات، أو المواد غير القانونية.\n"
          "3. العميل مسؤول عن صحة بيانات الموقع المحجوز.",
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 13),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _showConfirmationSheet,
              child: const Text("تأكيد", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
            )
          ],
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialLocation,
                initialZoom: 16.0,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    setState(() {
                      _draggedLocation = position.center!;
                      _address = "جاري التحديد...";
                    });
                  }
                },
                onPointerUp: (event, point) => _reverseGeocode(_draggedLocation),
              ),
              children: [
                TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'),
              ],
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 35),
                child: Icon(Icons.location_on, color: Colors.red, size: 50),
              ),
            ),
            Positioned(
              top: 20, left: 15, right: 15,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_address, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          height: 80,
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 25),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.white.withOpacity(0.7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavIcon(Icons.home_filled, "الرئيسية", () => Navigator.pushNamed(context, ConsumerHomeScreen.routeName)),
                    _buildNavIcon(Icons.history_edu_rounded, "طلباتي", () {}),
                    _buildNavIcon(Icons.gavel_rounded, "الشروط", _showTermsDialog),
                    _buildNavIcon(Icons.account_balance_wallet_outlined, "محفظتي", () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black87),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
