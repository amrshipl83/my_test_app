import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

// 🎯 استيراد الخدمة الجديدة
import '../../services/bubble_service.dart';
import '../../services/delivery_service.dart';

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
  String _tempAddress = "حرك الخريطة لتحديد الموقع";
  bool _isLoading = false;
  final bool _agreedToTerms = true;
  String _selectedVehicle = "motorcycle";

  final List<Map<String, dynamic>> _vehicles = [
    {"id": "motorcycle", "name": "موتوسيكل", "icon": Icons.directions_bike},
    {"id": "pickup", "name": "ربع نقل", "icon": Icons.local_shipping},
    {"id": "jumbo", "name": "جامبو (عفش)", "icon": Icons.fire_truck},
  ];

  @override
  void initState() {
    super.initState();
    _currentMapCenter = widget.initialLocation ?? const LatLng(31.2001, 29.9187);
    _determinePosition();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    if (widget.initialLocation != null) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentMapCenter = LatLng(position.latitude, position.longitude);
      _mapController.move(_currentMapCenter, 15);
      _getAddress(_currentMapCenter);
    });
  }

  Future<void> _getAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _tempAddress = "${place.street}, ${place.subLocality}, ${place.locality}";
        });
      }
    } catch (e) {
      setState(() { _tempAddress = "موقع غير مسمى"; });
    }
  }

  void _handleNextStep() async {
    if (_currentStep == PickerStep.pickup) {
      _pickupLocation = _currentMapCenter;
      _pickupAddress = _tempAddress;
      setState(() {
        _currentStep = PickerStep.dropoff;
        _tempAddress = "حدد وجهة التوصيل...";
      });
    } else if (_currentStep == PickerStep.dropoff) {
      _dropoffLocation = _currentMapCenter;
      _dropoffAddress = _tempAddress;
      _estimatedPrice = await _calculatePrice(_selectedVehicle);
      _showFinalConfirmation();
    }
  }

  Future<double> _calculatePrice(String vehicleType) async {
    if (_pickupLocation == null || _dropoffLocation == null) return 0.0;
    double distance = _deliveryService.calculateDistance(
        _pickupLocation!.latitude, _pickupLocation!.longitude,
        _dropoffLocation!.latitude, _dropoffLocation!.longitude
    );
    return await _deliveryService.calculateTripCost(
        distanceInKm: distance,
        vehicleType: vehicleType
    );
  }

  Future<void> _finalizeAndUpload() async {
    if (!_agreedToTerms) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      final docRef = await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': user?.uid ?? 'anonymous',
        'pickupLocation': GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
        'pickupAddress': _pickupAddress,
        'dropoffLocation': GeoPoint(_dropoffLocation!.latitude, _dropoffLocation!.longitude),
        'dropoffAddress': _dropoffAddress,
        'price': _estimatedPrice,
        'vehicleType': _selectedVehicle,
        'details': _detailsController.text,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 1. حفظ المعرف في الذاكرة المحلية
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_special_order_id', docRef.id);

      // 2. 🎯 تشغيل الفقاعة فوراً عبر خدمة الـ Overlay
      BubbleService.show(docRef.id);

      if (!mounted) return;

      // إغلاق الشاشات والعودة
      Navigator.pop(context); // إغلاق المودال
      Navigator.pop(context); // العودة للرئيسية

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم إرسال طلبك بنجاح! تتبع المندوب من الفقاعة الظاهرة."))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء الإرسال: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentStep == PickerStep.pickup ? "تحديد مكان الاستلام" : "تحديد وجهة التوصيل",
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900)),
          centerTitle: true,
          elevation: 0,
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
            
            // 🎯 تصغير أيقونة السنتر (Pin) لتصبح 28.sp بدلاً من 45.sp
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30), // تقليل الإزاحة لتناسب الحجم الجديد
                child: Icon(
                  Icons.location_on_sharp, 
                  size: 28.sp, // 👈 الحجم الجديد الأصغر
                  color: _currentStep == PickerStep.pickup ? Colors.green[700] : Colors.red[700],
                  shadows: const [Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
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
      bottom: 20, left: 15, right: 15,
      child: Card(
        elevation: 10,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.location_searching, color: Colors.blue[800], size: 18.sp),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_tempAddress, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp)),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: _handleNextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentStep == PickerStep.pickup ? Colors.green[800] : Colors.red[800],
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                child: Text(_currentStep == PickerStep.pickup ? "تأكيد مكان الاستلام" : "تأكيد وجهة التوصيل",
                    style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ... دالة _showFinalConfirmation و _buildSummaryItem تظل كما هي (مع التأكد من استخدام أحجام sp مناسبة)
  void _showFinalConfirmation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
                left: 20, right: 20, top: 15,
                bottom: MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom + 20
            ),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 15),
                  Text("إتمام الطلب", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp)),
                  const Divider(),
                  Align(alignment: Alignment.centerRight, child: Text("نوع المركبة:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp))),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _vehicles.length,
                      itemBuilder: (context, index) {
                        final v = _vehicles[index];
                        bool isSelected = _selectedVehicle == v['id'];
                        return GestureDetector(
                          onTap: () async {
                            setModalState(() => _selectedVehicle = v['id']);
                            double newPrice = await _calculatePrice(v['id']);
                            setModalState(() => _estimatedPrice = newPrice);
                          },
                          child: Container(
                            width: 90,
                            margin: const EdgeInsets.only(left: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: isSelected ? Colors.blue : Colors.grey[200]!),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(v['icon'], color: isSelected ? Colors.blue : Colors.grey, size: 20.sp),
                                Text(v['name'], style: TextStyle(fontSize: 8.sp, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _detailsController,
                    decoration: InputDecoration(
                      hintText: "ماذا تريد أن تنقل؟ (اختياري)",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildSummaryItem(Icons.circle, Colors.green, "من: $_pickupAddress"),
                  _buildSummaryItem(Icons.location_on, Colors.red, "إلى: $_dropoffAddress"),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("التكلفة التقديرية:", style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
                      Text("${_estimatedPrice.toStringAsFixed(2)} ج.م", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.w900, fontSize: 14.sp)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _finalizeAndUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text("تأكيد الطلب الآن", style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [Icon(icon, color: color, size: 14), const SizedBox(width: 10), Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.sp)))]),
    );
  }
}

