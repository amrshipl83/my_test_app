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
  
  // ✅ تم تغيير المركز الابتدائي ليكون موقع المستخدم الفعلي لاحقاً
  late LatLng _currentMapCenter;
  LatLng? _pickupLocation;
  String _pickupAddress = "جاري جلب العنوان...";
  LatLng? _dropoffLocation;
  String _dropoffAddress = "";
  
  double _estimatedPrice = 0.0;
  Map<String, double> _pricingDetails = {
    'totalPrice': 0.0,
    'commissionAmount': 0.0,
    'driverNet': 0.0
  };

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
    // ✅ نبدأ بالموقع الممرر (لو موجود) أو إحداثيات صفرية مؤقتاً حتى يعمل الـ GPS
    _currentMapCenter = widget.initialLocation ?? const LatLng(0, 0);
    _determinePosition();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String _generateOTP() {
    var rng = Random();
    return (1000 + rng.nextInt(9000)).toString();
  }

  Future<void> _determinePosition() async {
    // 1. لو الشاشة جاية بموقع محدد مسبقاً
    if (widget.initialLocation != null) {
      _getAddress(widget.initialLocation!);
      return;
    }

    // 2. التحقق من أذونات الموقع
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // 3. جلب الموقع الحالي بدقة عالية
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      LatLng myLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentMapCenter = myLocation;
          // ✅ تحريك الكاميرا فوراً لموقع المستخدم الفعلي (الإسكندرية أو غيرها)
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
            _tempAddress = "${place.street}, ${place.subLocality}, ${place.locality}";
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _tempAddress = "موقع غير مسمى"; });
    }
  }

  Future<void> _updatePricing(String vehicleType) async {
    if (_pickupLocation == null || _dropoffLocation == null) return;
    
    try {
      double distance = _deliveryService.calculateDistance(
          _pickupLocation!.latitude, _pickupLocation!.longitude,
          _dropoffLocation!.latitude, _dropoffLocation!.longitude
      );

      final results = await _deliveryService.calculateDetailedTripCost(
          distanceInKm: distance,
          vehicleType: vehicleType
      );

      setState(() {
        _pricingDetails = results;
        _estimatedPrice = results['totalPrice']!;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("خطأ في حساب السعر لـ $vehicleType"))
        );
      }
    }
  }

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

  Future<void> _finalizeAndUpload() async {
    if (_pricingDetails['totalPrice'] == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("برجاء اختيار وسيلة نقل صحيحة أولاً"))
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String rawEmail = user?.email ?? ""; 
      String derivedPhone = rawEmail.contains('@') ? rawEmail.split('@')[0] : (user?.phoneNumber ?? "0000000000");

      final String securityCode = _generateOTP();

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
        'verificationCode': securityCode,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_special_order_id', docRef.id);
      
      BubbleService.show(docRef.id);

      if (!mounted) return;
      Navigator.pop(context); // إغلاق المودال
      Navigator.pop(context); // العودة من الخريطة
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("🚀 طلبك وصل للمناديب!"))
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
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
          title: Text(
            _currentStep == PickerStep.pickup ? "1. مكان الاستلام" : "2. وجهة التوصيل",
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.black),
          ),
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
                  if (hasGesture) {
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
                padding: const EdgeInsets.only(bottom: 35),
                child: Icon(
                  Icons.location_on_sharp,
                  size: 50,
                  color: _currentStep == PickerStep.pickup ? Colors.green[800] : Colors.red[800],
                ),
              ),
            ),
            _buildActionCard(),
            if (_isLoading) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    return Positioned(
      bottom: 25, left: 15, right: 15,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.location_searching, color: Colors.blue[800], size: 28),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(_tempAddress, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                onPressed: _handleNextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentStep == PickerStep.pickup ? Colors.green[800] : Colors.red[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(
                  _currentStep == PickerStep.pickup ? "تأكيد مكان الاستلام" : "تأكيد وجهة التوصيل",
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showFinalConfirmation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(25, 20, 25, MediaQuery.of(context).padding.bottom + 30),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("إتمام طلب التوصيل", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  const Divider(height: 30),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _vehicles.length,
                      itemBuilder: (context, index) {
                        final v = _vehicles[index];
                        bool isSelected = _selectedVehicle == v['id'];
                        return GestureDetector(
                          onTap: () async {
                            setModalState(() => _selectedVehicle = v['id']);
                            await _updatePricing(v['id']);
                            setModalState(() {}); 
                          },
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(left: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? Colors.blue : Colors.grey[200]!, width: 2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(v['icon'], color: isSelected ? Colors.blue : Colors.grey, size: 35),
                                Text(v['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: _detailsController,
                    decoration: InputDecoration(
                      hintText: "ملاحظات للمندوب...",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildSummaryItem(Icons.circle, Colors.green, "من: $_pickupAddress"),
                  _buildSummaryItem(Icons.location_on, Colors.red, "إلى: $_dropoffAddress"),
                  const Divider(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("التكلفة:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("${_estimatedPrice.toStringAsFixed(2)} ج.م", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 22)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _finalizeAndUpload,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      child: const Text("تأكيد وإرسال", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
