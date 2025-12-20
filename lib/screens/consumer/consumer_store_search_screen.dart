// lib/screens/consumer/consumer_store_search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance;
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/screens/consumer/MarketplaceHomeScreen.dart';
import 'package:my_test_app/screens/special_requests/location_picker_screen.dart';

class ConsumerStoreSearchScreen extends StatefulWidget {
  static const routeName = '/consumerStoreSearch';
  const ConsumerStoreSearchScreen({super.key});

  @override
  State<ConsumerStoreSearchScreen> createState() => _ConsumerStoreSearchScreenState();
}

class _ConsumerStoreSearchScreenState extends State<ConsumerStoreSearchScreen> {
  LatLng? _currentSearchLocation;
  bool _isLoading = false;
  String _loadingMessage = 'اضغط على الموقع لبدء المسح الجغرافي';
  List<Map<String, dynamic>> _nearbySupermarkets = [];
  List<Marker> _mapMarkers = [];
  final MapController _mapController = MapController();
  final double _searchRadiusKm = 5.0;
  final LatLng _defaultLocation = const LatLng(31.2001, 29.9187);
  final Distance distance = const Distance();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptLocationSelection();
    });
  }

  // ... (نفس دوال الموقع والبحث السابقة بدون تغيير) ...
  Future<Position?> _getCurrentLocation() async {
    setState(() { _isLoading = true; _loadingMessage = 'جاري تحديد إحداثياتك الحالية...'; });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception('يرجى تفعيل إذن الموقع يدوياً');
        }
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
      return null;
    }
  }

  Future<void> _promptLocationSelection() async {
    final buyerDataProvider = Provider.of<BuyerDataProvider>(context, listen: false);
    final LatLng? registeredLocation = (buyerDataProvider.userLat != null && buyerDataProvider.userLng != null)
        ? LatLng(buyerDataProvider.userLat!, buyerDataProvider.userLng!)
        : null;

    final selectedOption = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => _buildLocationSelectionSheet(registeredLocation != null),
    );

    if (selectedOption == 'current') {
      final position = await _getCurrentLocation();
      if (position != null) {
        _currentSearchLocation = LatLng(position.latitude, position.longitude);
        _searchAndDisplayStores(_currentSearchLocation!);
      }
    } else if (selectedOption == 'registered' && registeredLocation != null) {
      _currentSearchLocation = registeredLocation;
      _searchAndDisplayStores(_currentSearchLocation!);
    } else {
      _mapController.move(_defaultLocation, 12);
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _searchAndDisplayStores(LatLng location) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'جاري مسح المنطقة...';
      _nearbySupermarkets = [];
      _mapMarkers = [];
    });
    try {
      _mapController.move(location, 14.5);
      _mapMarkers.add(Marker(point: location, width: 60, height: 60, child: _buildUserLocationMarker()));

      final QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('deliverySupermarkets').get();
      final List<Map<String, dynamic>> foundStores = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        LatLng? storeLoc;
        if (data['location'] is GeoPoint) {
          storeLoc = LatLng(data['location'].latitude, data['location'].longitude);
        } else if (data['location'] is Map) {
          storeLoc = LatLng(data['location']['lat'] as double, data['location']['lng'] as double);
        }

        if (storeLoc != null) {
          final distInKm = distance(location, storeLoc) / 1000;
          if (distInKm <= _searchRadiusKm) {
            final storeData = {'id': doc.id, ...data, 'location': storeLoc, 'distance': distInKm.toStringAsFixed(2)};
            foundStores.add(storeData);
            _mapMarkers.add(Marker(point: storeLoc, width: 50, height: 50, child: _buildStoreMarker(storeData)));
          }
        }
      }

      foundStores.sort((a, b) => double.parse(a['distance']).compareTo(double.parse(b['distance'])));
      setState(() {
        _nearbySupermarkets = foundStores;
        _isLoading = false;
        _loadingMessage = foundStores.isEmpty ? 'لا توجد متاجر قريبة' : 'تم العثور على ${foundStores.length} متاجر';
      });
    } catch (e) { setState(() { _isLoading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('اكتشف المتاجر', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 15.sp)),
          centerTitle: true,
          backgroundColor: Colors.white.withOpacity(0.9),
          elevation: 2,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _currentSearchLocation ?? _defaultLocation, initialZoom: 13.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(markers: _mapMarkers),
              ],
            ),

            // الهيدر العائم
            Positioned(top: 13.h, left: 15, right: 15, child: _buildFloatingActionHeader()),

            // زر ابعتلي حد - تم رفعه وتغيير مكانه ليكون فوق قائمة المتاجر بوضوح
            if (_currentSearchLocation != null)
              Positioned(
                bottom: _nearbySupermarkets.isNotEmpty ? 22.h : 5.h,
                left: 20,
                child: FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => LocationPickerScreen(initialLocation: _currentSearchLocation!)));
                  },
                  label: Text("ابعتلي حد", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.white)),
                  icon: Icon(Icons.directions_run_rounded, color: Colors.white, size: 20.sp),
                  backgroundColor: Colors.orange[900],
                  elevation: 10,
                ),
              ),

            // قائمة المتاجر السفلية
            Positioned(bottom: 0, left: 0, right: 0, child: _buildStoresPreviewList()),

            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.green[800], size: 22.sp),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentSearchLocation == null ? "حدد موقعك للبحث" : "نطاق البحث: $_searchRadiusKm كم",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.black87),
            ),
          ),
          GestureDetector(
            onTap: _promptLocationSelection,
            child: CircleAvatar(
              radius: 18.sp,
              backgroundColor: Colors.green[800],
              child: Icon(Icons.my_location, color: Colors.white, size: 16.sp),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStoresPreviewList() {
    if (_nearbySupermarkets.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        height: 18.h, // زيادة الارتفاع ليتناسب مع الخطوط الكبيرة
        margin: EdgeInsets.only(bottom: 3.h),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          itemCount: _nearbySupermarkets.length,
          itemBuilder: (context, index) {
            final store = _nearbySupermarkets[index];
            return _buildStoreSmallCard(store);
          },
        ),
      ),
    );
  }

  Widget _buildStoreSmallCard(Map<String, dynamic> store) {
    return Container(
      width: 75.w, // عرض مرن بناءً على حجم الشاشة
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => _showStoreDetailsBottomSheet(store),
        borderRadius: BorderRadius.circular(25),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 15.w, height: 15.w,
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(15)),
                child: Icon(Icons.storefront_rounded, color: Colors.green[800], size: 25.sp),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store['supermarketName'] ?? 'متجر',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("${store['distance']} كم بعيداً عنك", 
                        style: TextStyle(color: Colors.grey[700], fontSize: 11.sp, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14.sp, color: Colors.green[800]),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Markers و Loading Overlay بدون تغيير جذري، فقط تكبير الأيقونات) ...
  Widget _buildUserLocationMarker() => Icon(Icons.person_pin_circle, color: Colors.blue[800], size: 35.sp);
  Widget _buildStoreMarker(Map<String, dynamic> store) => Icon(Icons.location_on, color: Colors.green[800], size: 30.sp);

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 25),
              Text(_loadingMessage, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelectionSheet(bool hasRegistered) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(25, 15, 25, 30),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            Text("تحديد موقع البحث", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            _buildLocationOption(
              icon: Icons.my_location,
              title: "موقعي الحالي",
              subtitle: "تحديد مكانك الآن عبر GPS",
              onTap: () => Navigator.pop(context, 'current')),
            if (hasRegistered) ...[
              const SizedBox(height: 15),
              _buildLocationOption(
                icon: Icons.home_rounded,
                title: "عنواني المسجل",
                subtitle: "استخدام الموقع المحفوظ مسبقاً",
                onTap: () => Navigator.pop(context, 'registered')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(radius: 22, backgroundColor: Colors.green.withOpacity(0.1), child: Icon(icon, color: Colors.green[800])),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey[200]!, width: 1.5)),
    );
  }

  void _showStoreDetailsBottomSheet(Map<String, dynamic> store) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => StoreDetailsBottomSheet(store: store));
  }
}

class StoreDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> store;
  const StoreDetailsBottomSheet({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.storefront_rounded, color: Colors.green[800], size: 32.sp),
                const SizedBox(width: 15),
                Expanded(child: Text(store['supermarketName'] ?? 'المتجر', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold))),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, size: 22.sp)),
              ],
            ),
            const Divider(height: 30),
            _buildInfoRow(Icons.location_on_outlined, store['address'] ?? 'العنوان غير متاح'),
            _buildInfoRow(Icons.directions_walk, "يبعد مسافة ${store['distance']} كم عنك"),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed(MarketplaceHomeScreen.routeName, arguments: {'storeId': store['id'], 'storeName': store['supermarketName']});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 5,
              ),
              child: Text("دخول المتجر وتصفح العروض", style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700], size: 22.sp),
          const SizedBox(width: 15),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: Colors.black87))),
        ],
      ),
    );
  }
}
