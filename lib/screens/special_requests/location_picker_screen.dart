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
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final DeliveryService _deliveryService = DeliveryService();
  final TextEditingController _detailsController = TextEditingController();

  PickerStep _currentStep = PickerStep.pickup;
  late LatLng _currentMapCenter;

  LatLng? _pickupLocation;
  String _pickupAddress = "جاري جلب العنوان...";
  LatLng? _dropoffLocation;
  String _dropoffAddress = "";
  double _estimatedPrice = 0.0;
  String _tempAddress = "حرك الخريطة لتحديد الموقع";
  bool _isLoading = false;
  bool _agreedToTerms = true;

  // متغيرات نوع المركبة
  String _selectedVehicle = "motorcycle"; 
  final List<Map<String, dynamic>> _vehicles = [
    {"id": "motorcycle", "name": "موتوسيكل", "icon": Icons.directions_bike, "desc": "للطلبات الخفيفة"},
    {"id": "pickup", "name": "ربع نقل", "icon": Icons.local_shipping, "desc": "بضائع متوسطة"},
    {"id": "jumbo", "name": "جامبو (عفش)", "icon": Icons.fire_truck, "desc": "نقل ثقيل وعفش"},
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
      _estimatedPrice = await _calculatePrice();
      _showFinalConfirmation();
    }
  }

  Future<double> _calculatePrice() async {
    if (_pickupLocation == null || _dropoffLocation == null) return 0.0;
    double distance = _deliveryService.calculateDistance(
      _pickupLocation!.latitude, _pickupLocation!.longitude,
      _dropoffLocation!.latitude, _dropoffLocation!.longitude
    );
    return await _deliveryService.calculateTripCost(distanceInKm: distance);
  }

  Future<void> _finalizeAndUpload() async {
    if (!_agreedToTerms) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': user?.uid ?? 'anonymous',
        'pickupLocation': GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
        'pickupAddress': _pickupAddress,
        'dropoffLocation': GeoPoint(_dropoffLocation!.latitude, _dropoffLocation!.longitude),
        'dropoffAddress': _dropoffAddress,
        'price': _estimatedPrice,
        'vehicleType': _selectedVehicle,
        'details': _detailsController.text,
        'agreedToTerms': _agreedToTerms,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context); // إغلاق المنبثقة
      Navigator.pop(context); // العودة للخلف
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إرسال طلبك بنجاح! جاري البحث عن مندوب...")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == PickerStep.pickup ? "تحديد مكان الاستلام" : "تحديد وجهة التوصيل", 
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold)),
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
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.app',
              ),
            ],
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 35),
              child: Icon(Icons.location_pin, size: 45, color: _currentStep == PickerStep.pickup ? Colors.green : Colors.red),
            ),
          ),
          _buildActionCard(),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Positioned(
      bottom: 20, left: 20, right: 20,
      child: SafeArea(
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.map_outlined, color: Colors.grey[600]),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_tempAddress, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 10.sp))),
                  ],
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: _handleNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentStep == PickerStep.pickup ? Colors.green[700] : Colors.red[700],
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(_currentStep == PickerStep.pickup ? "تأكيد مكان الاستلام" : "تأكيد وجهة التوصيل", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
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
          return SafeArea(
            child: Container(
              padding: EdgeInsets.only(left: 20, right: 20, top: 15, bottom: MediaQuery.of(context).viewInsets.bottom + 15),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 15),
                    Text("تفاصيل الطلب النهائي", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                    const Divider(),
                    
                    // اختيار نوع المركبة
                    Align(alignment: Alignment.centerRight, child: Text("وسيلة النقل المطلوبة:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp))),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _vehicles.length,
                        itemBuilder: (context, index) {
                          final v = _vehicles[index];
                          bool isSelected = _selectedVehicle == v['id'];
                          return GestureDetector(
                            onTap: () => setModalState(() => _selectedVehicle = v['id']),
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(left: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.orange.withOpacity(0.1) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: isSelected ? Colors.orange : Colors.transparent, width: 2),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(v['icon'], color: isSelected ? Colors.orange : Colors.grey),
                                  Text(v['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.sp)),
                                  Text(v['desc'], style: TextStyle(fontSize: 7.sp, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    // وصف الشحنة
                    TextField(
                      controller: _detailsController,
                      maxLines: 2,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: "ماذا تريد أن تنقل؟ (مثال: كرتونة طلبات، طقم أنتريه...)",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    _buildInfoRow(Icons.circle, Colors.green, "من: $_pickupAddress"),
                    _buildInfoRow(Icons.location_on, Colors.red, "إلى: $_dropoffAddress"),
                    
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("التكلفة التقديرية:"),
                        Text("${_estimatedPrice.toStringAsFixed(2)} ج.م", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18.sp)),
                      ],
                    ),
                    
                    CheckboxListTile(
                      value: _agreedToTerms,
                      onChanged: (val) => setModalState(() => _agreedToTerms = val!),
                      title: Text("أوافق على الشروط والخصوصية", style: TextStyle(fontSize: 9.sp)),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                    ElevatedButton(
                      onPressed: _agreedToTerms ? _finalizeAndUpload : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("تأكيد وطلب الآن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.sp))),
        ],
      ),
    );
  }
}
