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
      await FirebaseFirestore.instance.collection('specialRequests').add({
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
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إرسال طلبك بنجاح!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
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
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900)),
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
                ),
              ],
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 35),
                child: Icon(Icons.location_pin, size: 50, color: _currentStep == PickerStep.pickup ? Colors.green[700] : Colors.red[700]),
              ),
            ),
            _buildActionCard(),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    return Positioned(
      bottom: 20, left: 15, right: 15,
      child: SafeArea( // تأمين الكارت من الحواف السفلية للشاشة
        child: Card(
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_searching, color: Colors.blue[800], size: 30),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        _tempAddress,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _handleNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentStep == PickerStep.pickup ? Colors.green[800] : Colors.red[800],
                    minimumSize: const Size(double.infinity, 65),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    _currentStep == PickerStep.pickup ? "تأكيد مكان الاستلام" : "تأكيد وجهة التوصيل",
                    style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900),
                  ),
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
          return Container(
            padding: EdgeInsets.only(
              left: 20, 
              right: 20, 
              top: 15, 
              bottom: MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom + 20
            ),
            decoration: const BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.vertical(top: Radius.circular(35))
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Text("تفاصيل الطلب النهائي", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp)),
                  const Divider(height: 30),
                  
                  Align(alignment: Alignment.centerRight, child: Text("وسيلة النقل المطلوبة:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp))),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
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
                            width: 110,
                            margin: const EdgeInsets.only(left: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.orange.withOpacity(0.1) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? Colors.orange[800]! : Colors.grey[200]!, width: 2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(v['icon'], color: isSelected ? Colors.orange[800] : Colors.grey[600], size: 30),
                                const SizedBox(height: 8),
                                Text(v['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("ماذا تريد أن تنقل؟ (اختياري)", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.blueGrey[800])),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _detailsController,
                          maxLines: 1,
                          style: TextStyle(fontSize: 12.sp),
                          decoration: InputDecoration(
                            hintText: "مثال: كرتونة طلبات، طقم أنتريه...",
                            hintStyle: TextStyle(fontSize: 11.sp),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                  _buildInfoRow(Icons.circle, Colors.green[700]!, "من: $_pickupAddress"),
                  _buildInfoRow(Icons.location_on, Colors.red[700]!, "إلى: $_dropoffAddress"),
                  
                  const Divider(height: 35),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("التكلفة التقديرية:", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                      Text("${_estimatedPrice.toStringAsFixed(2)} ج.م",
                        style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.w900, fontSize: 20.sp)),
                    ],
                  ),
                  
                  const SizedBox(height: 15),
                  CheckboxListTile(
                    value: _agreedToTerms,
                    onChanged: (val) => setModalState(() => _agreedToTerms = val!),
                    title: Text("أوافق على الشروط. (المنصة وسيط تقني فقط)",
                      style: TextStyle(fontSize: 10.sp, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  ElevatedButton(
                    onPressed: _agreedToTerms ? _finalizeAndUpload : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[900],
                      minimumSize: const Size(double.infinity, 70),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text("تأكيد وطلب الآن", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
