// lib/screens/special_requests/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/delivery_service.dart';
import 'package:sizer/sizer.dart';

enum PickerStep { pickup, dropoff, confirm }

class LocationPickerScreen extends StatefulWidget {
  static const routeName = '/location-picker';
  
  // 🛑 تم إضافة المتغير هنا لحل مشكلة الشاشة الأخرى
  final LatLng? initialLocation; 

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final DeliveryService _deliveryService = DeliveryService();
  
  PickerStep _currentStep = PickerStep.pickup;
  // 🛑 نستخدم الموقع الممرر إذا وجد، وإلا القاهرة كافتراضي
  late LatLng _currentMapCenter; 
  
  LatLng? _pickupLocation;
  String _pickupAddress = "جاري جلب العنوان...";
  LatLng? _dropoffLocation;
  String _dropoffAddress = "";
  double _estimatedPrice = 0.0;
  String _tempAddress = "حرك الخريطة لتحديد الموقع";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentMapCenter = widget.initialLocation ?? const LatLng(30.0444, 31.2357);
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    if (widget.initialLocation != null) return; // لا نحتاج جلب الموقع لو تم تمريره

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentMapCenter = LatLng(position.latitude, position.longitude);
      _mapController.move(_currentMapCenter, 15);
    });
  }

  // ... (باقي الدوال كما هي: _getAddress, _handleNextStep, _calculatePrice, _finalizeAndUpload) ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == PickerStep.pickup ? "تحديد مكان الاستلام" : "تحديد وجهة التوصيل"),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // 🛑 تم تغيير center إلى initialCenter ليتناسب مع الإصدار الجديد
              initialCenter: _currentMapCenter, 
              initialZoom: 15.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  _currentMapCenter = pos.center!;
                  // _getAddress(_currentMapCenter); // تأكد من استدعاء دالة العناوين هنا
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.app',
              ),
            ],
          ),
          const Center(child: Icon(Icons.location_pin, size: 40, color: Colors.red)),
          // أضف هنا واجهة الأزرار التي برمجناها سابقاً
        ],
      ),
    );
  }
}
