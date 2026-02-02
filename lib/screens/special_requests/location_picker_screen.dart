// lib/screens/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import '../../services/bubble_service.dart';
import '../../services/delivery_service.dart';
import 'dart:math';

enum PickerStep { pickup, dropoff, confirm }

class LocationPickerScreen extends StatefulWidget {
  static const routeName = '/location-picker';
  final LatLng? initialLocation;
  final String title;

  const LocationPickerScreen({super.key, this.initialLocation, this.title = "تحديد الموقع"});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final DeliveryService _deliveryService = DeliveryService();
  final TextEditingController _detailsController = TextEditingController();

  final String mapboxToken = "pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw";

  PickerStep _currentStep = PickerStep.pickup;
  
  late LatLng _currentMapCenter;
  LatLng? _pickupLocation;
  String _pickupAddress = "جاري جلب العنوان...";
  LatLng? _dropoffLocation;
  String _dropoffAddress = "";
  
  double _estimatedPrice = 0.0;
  Map<String, double> _pricingDetails = {'totalPrice': 0.0, 'commissionAmount': 0.0, 'driverNet': 0.0};

  String _tempAddress = "جاري تحديد موقعك الحالي...";
  bool _isLoading = false;
  String _selectedVehicle = "motorcycle";

  final List<Map<String, dynamic>> _vehicles = [
    {"id": "motorcycle", "name": "موتوسيكل", "icon": Icons.directions_bike},
    {"id": "pickup", "name": "ربع نقل", "icon": Icons.local_shipping},
    {"id": "jumbo", "name": "جامبو", "icon": Icons.fire_truck},
  ];

  @override
  void initState() {
    super.initState();
    _currentMapCenter = widget.initialLocation ?? const LatLng(30.0444, 31.2357); // القاهرة كافتراضي آمن
    _determinePosition();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  // ✅ إضافة رسالة الاطمئنان الاحترافية
  Future<void> _showLocationExplanation() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("تفعيل خرائط أكسب", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          content: const Text("عشان نحدد مكان الاستلام بدقة ونوصلك بأقرب مندوب، بنحتاج منك تفعيل إذن الوصول للموقع الجغرافي."),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("موافق، فهمت", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _determinePosition() async {
    if (widget.initialLocation != null) {
      _getAddress(widget.initialLocation!);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    
    // ✅ لا تظهر الرسالة إلا لو الإذن مرفوض
    if (permission == LocationPermission.denied) {
      await _showLocationExplanation();
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng myLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentMapCenter = myLocation;
          _mapController.move(myLocation, 15);
          _getAddress(myLocation);
        });
      }
    } catch (e) {
      debugPrint("Location Error: $e");
    }
  }

  Future<void> _getAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (mounted) {
          setState(() {
            // ✅ استخدام ?? آمن لمنع الـ Null
            _tempAddress = "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}";
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _tempAddress = "موقع غير مسمى"; });
    }
  }

  // ✅ إصلاح دالة الانتقال بين الخطوات
  void _handleNextStep() async {
    if (_currentStep == PickerStep.pickup) {
      _pickupLocation = _currentMapCenter;
      _pickupAddress = _tempAddress;
      setState(() {
        _currentStep = PickerStep.dropoff;
        _tempAddress = "حدد وجهة التوصيل الآن...";
      });
    } else if (_currentStep == PickerStep.dropoff) {
      _dropoffLocation = _currentMapCenter;
      _dropoffAddress = _tempAddress;
      
      await _updatePricing(_selectedVehicle);
      _showFinalConfirmation();
    }
  }

  // ... (دوال السعر والرفع تبقى كما هي)
  Future<void> _updatePricing(String vehicleType) async {
    if (_pickupLocation == null || _dropoffLocation == null) return;
    try {
      double distance = _deliveryService.calculateDistance(
          _pickupLocation!.latitude, _pickupLocation!.longitude,
          _dropoffLocation!.latitude, _dropoffLocation!.longitude);
      final results = await _deliveryService.calculateDetailedTripCost(distanceInKm: distance, vehicleType: vehicleType);
      setState(() {
        _pricingDetails = results;
        _estimatedPrice = results['totalPrice']!;
      });
    } catch (e) {
       debugPrint("Pricing Error: $e");
    }
  }

  Future<void> _finalizeAndUpload() async {
    if (_pricingDetails['totalPrice'] == 0) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String rawEmail = user?.email ?? ""; 
      String derivedPhone = rawEmail.contains('@') ? rawEmail.split('@')[0] : (user?.phoneNumber ?? "0000000000");

      final docRef = await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': user?.uid ?? 'anonymous',
        'userPhone': derivedPhone,
        'pickupLocation': GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
        'pickupAddress': _pickupAddress,
        'dropoffLocation': GeoPoint(_dropoffLocation!.latitude, _dropoffLocation!.longitude),
        'dropoffAddress': _dropoffAddress,
        'totalPrice': _pricingDetails['totalPrice'],
        'commissionAmount': _pricingDetails['commissionAmount'],
        'driverNet': _pricingDetails['driverNet'],
        'vehicleType': _selectedVehicle,
        'details': _detailsController.text,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_special_order_id', docRef.id);
      
      BubbleService.show(docRef.id);

      if (!mounted) return;
      Navigator.of(context).pop(); // غلق الـ BottomSheet
      Navigator.of(context).pop(); // الرجوع للرئيسية
    } catch (e) {
      debugPrint("Upload Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 2,
          title: Text(_currentStep == PickerStep.pickup ? "1. مكان الاستلام" : "2. وجهة التوصيل",
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.black)),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentMapCenter,
                initialZoom: 15.0,
                onPositionChanged: (pos, hasGesture) {
                  // ✅ الحل السحري: فحص الـ Null قبل الإسناد
                  if (hasGesture && pos.center != null) {
                    _currentMapCenter = pos.center!;
                    _getAddress(_currentMapCenter);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken',
                  additionalOptions: {'accessToken': mapboxToken},
                ),
              ],
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(35),
                child: Icon(Icons.location_on_sharp, size: 50, color: _currentStep == PickerStep.pickup ? Colors.green[800] : Colors.red[800]),
              ),
            ),
            _buildActionCard(),
            if (_isLoading) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }

  // ... (بقية الـ Widgets تبقى كما هي)
  Widget _buildActionCard() {
    return Positioned(
      bottom: 25, left: 15, right: 15,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
                Icon(Icons.location_searching, color: Colors.blue[800], size: 28),
                const SizedBox(width: 15),
                Expanded(child: Text(_tempAddress, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
            ]),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 65,
              child: ElevatedButton(
                onPressed: _handleNextStep,
                style: ElevatedButton.styleFrom(backgroundColor: _currentStep == PickerStep.pickup ? Colors.green[800] : Colors.red[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: Text(_currentStep == PickerStep.pickup ? "تأكيد مكان الاستلام" : "تأكيد وجهة التوصيل", style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showFinalConfirmation() {
    // ... (نفس كود المودال السابق)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(25, 20, 25, MediaQuery.of(ctx).padding.bottom + 30),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("إتمام طلب التوصيل", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const Divider(height: 30),
              // ... بقية عناصر المودال
              SizedBox(width: double.infinity, height: 60,
                child: ElevatedButton(
                  onPressed: _finalizeAndUpload,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: const Text("تأكيد وإرسال", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
