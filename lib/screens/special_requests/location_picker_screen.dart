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
  
  // المتغيرات المالية الجديدة
  double _estimatedPrice = 0.0;
  Map<String, double> _pricingDetails = {
    'totalPrice': 0.0,
    'commissionAmount': 0.0,
    'driverNet': 0.0
  };

  String _tempAddress = "حرك الخريطة لتحديد الموقع";
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
    _currentMapCenter = widget.initialLocation ?? const LatLng(31.2001, 29.9187);
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
    if (widget.initialLocation != null) {
      _getAddress(widget.initialLocation!);
      return;
    }
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

  // دالة موحدة لتحديث السعر من السيرفس الجديد
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
      debugPrint("Pricing Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("خطأ: لم يتم العثور على إعدادات $vehicleType"))
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
    // التأكد من وجود حسبة سعرية قبل الرفع
    if (_pricingDetails['totalPrice'] == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("برجاء اختيار وسيلة نقل صحيحة أولاً"))
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // 🛡️ استخراج رقم التليفون من إيميل المستخدم المسجل (رقم@aksab.com)
      // دي الخطوة اللي هتخلي أيقونة الاتصال عند المندوب تشتغل
      String rawEmail = user?.email ?? ""; 
      String derivedPhone = rawEmail.contains('@') 
          ? rawEmail.split('@')[0] 
          : (user?.phoneNumber ?? "0000000000");

      final String securityCode = _generateOTP();

      // إنشاء المستند في الفايربيز مع الحقول المالية المؤمنة
      final docRef = await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': user?.uid ?? 'anonymous',
        'userPhone': derivedPhone, // الحقل السري اللي بيظهر للمندوب بعد القبول ✅
        'pickupLocation': GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
        'pickupAddress': _pickupAddress,
        'dropoffLocation': GeoPoint(_dropoffLocation!.latitude, _dropoffLocation!.longitude),
        'dropoffAddress': _dropoffAddress,
        
        // المبالغ المالية (الأساسية لعمل الرادار)
        'totalPrice': _pricingDetails['totalPrice'],       // للعميل
        'commissionAmount': _pricingDetails['commissionAmount'], // للمنصة
        'driverNet': _pricingDetails['driverNet'],         // للمندوب
        
        'vehicleType': _selectedVehicle,
        'details': _detailsController.text,
        'status': 'pending',
        'verificationCode': securityCode,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // حفظ معرف الطلب محلياً للرجوع إليه
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_special_order_id', docRef.id);
      
      // تشغيل فقاعة التتبع العائمة للعميل
      BubbleService.show(docRef.id);

      if (!mounted) return;
      
      // إغلاق الشاشات المنبثقة والعودة للرئيسية
      Navigator.pop(context); // إغلاق المودال
      Navigator.pop(context); // العودة من الخريطة
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("🚀 طلبك وصل للمناديب القريبين!")
        )
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ أثناء الرفع: $e"))
        );
      }
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
                  shadows: const [Shadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 5))],
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
                  child: Text(_tempAddress, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Colors.black87)),
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
                  elevation: 5,
                ),
                child: Text(
                  _currentStep == PickerStep.pickup ? "تأكيد مكان الاستلام" : "تأكيد وجهة التوصيل",
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
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
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  const Text("إتمام طلب التوصيل", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  const Divider(height: 30),
                  const Align(alignment: Alignment.centerRight, child: Text("اختر وسيلة النقل:", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
                  const SizedBox(height: 15),
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
                            // تحديث الحسبة عند تغيير المركبة داخل المودال
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
                                const SizedBox(height: 5),
                                Text(v['name'], style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold)),
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
                    maxLines: 2,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "ملاحظات إضافية للمندوب...",
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
                      const Text("التكلفة الإجمالية:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      Text("${_estimatedPrice.toStringAsFixed(2)} ج.م", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.w900, fontSize: 22)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: ElevatedButton(
                      onPressed: _finalizeAndUpload,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      child: const Text("تأكيد وإرسال الطلب", style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 15),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
