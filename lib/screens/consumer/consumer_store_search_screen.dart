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

  Future<Position?> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'جاري تحديد إحداثياتك الحالية...';
    });
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
      isDismissible: false, // منع الإغلاق لضمان تحديد موقع
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
      _loadingMessage = 'جاري مسح المنطقة المحيطة...';
      _nearbySupermarkets = [];
      _mapMarkers = [];
    });
    try {
      _mapController.move(location, 14.5);
      _mapMarkers.add(Marker(
        point: location,
        width: 60, height: 60,
        child: _buildUserLocationMarker(),
      ));

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
            final storeData = {
              'id': doc.id,
              ...data,
              'location': storeLoc,
              'distance': distInKm.toStringAsFixed(2),
            };
            foundStores.add(storeData);
            _mapMarkers.add(Marker(
              point: storeLoc,
              width: 50, height: 50,
              child: _buildStoreMarker(storeData),
            ));
          }
        }
      }

      foundStores.sort((a, b) => double.parse(a['distance']).compareTo(double.parse(b['distance'])));

      setState(() {
        _nearbySupermarkets = foundStores;
        _isLoading = false;
        _loadingMessage = foundStores.isEmpty ? 'لا توجد متاجر قريبة' : 'تم العثور على ${foundStores.length} متاجر';
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('اكتشف المتاجر', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14.sp)),
          centerTitle: true,
          backgroundColor: Colors.white.withOpacity(0.8),
          elevation: 0,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentSearchLocation ?? _defaultLocation,
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(markers: _mapMarkers),
              ],
            ),
            
            // الهيدر العائم العلوي
            Positioned(
              top: 12.h, left: 20, right: 20,
              child: _buildFloatingActionHeader(),
            ),

            // زر ابعتلي حد المطور
            if (_currentSearchLocation != null)
              Positioned(
                bottom: 25.h,
                left: 20,
                child: FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationPickerScreen(
                          initialLocation: _currentSearchLocation!,
                        ),
                      ),
                    );
                  },
                  label: Text("ابعتلي حد", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp, color: Colors.white)),
                  icon: const Icon(Icons.directions_run_rounded, color: Colors.white),
                  backgroundColor: Colors.orange[800],
                  elevation: 8,
                ),
              ),

            // قائمة المتاجر السفلية
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildStoresPreviewList(),
            ),

            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.green[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _currentSearchLocation == null ? "حدد موقعك للبحث" : "يتم البحث في نطاق $_searchRadiusKm كم",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10.sp),
            ),
          ),
          IconButton(
            onPressed: _promptLocationSelection,
            icon: CircleAvatar(
              backgroundColor: Colors.green[700],
              child: const Icon(Icons.my_location, color: Colors.white, size: 18),
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
        height: 160,
        margin: const EdgeInsets.only(bottom: 20),
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
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      child: InkWell(
        onTap: () => _showStoreDetailsBottomSheet(store),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront_rounded, color: Colors.green, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store['supermarketName'] ?? 'متجر', 
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp)),
                    Text("${store['distance']} كم بعيداً عنك", style: TextStyle(color: Colors.grey, fontSize: 9.sp)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(width: 35, height: 35, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), shape: BoxShape.circle)),
        Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)))),
      ],
    );
  }

  Widget _buildStoreMarker(Map<String, dynamic> store) {
    return GestureDetector(
      onTap: () => _showStoreDetailsBottomSheet(store),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)]),
            child: const Icon(Icons.shopping_basket, color: Colors.green, size: 18),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 20),
              Text(_loadingMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelectionSheet(bool hasRegistered) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(25, 10, 25, 25),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("تحديد موقع البحث", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildLocationOption(
              icon: Icons.my_location,
              title: "موقعي الحالي",
              subtitle: "استخدام GPS لتحديد مكانك الآن",
              onTap: () => Navigator.pop(context, 'current')),
            if (hasRegistered) ...[
              const SizedBox(height: 12),
              _buildLocationOption(
                icon: Icons.home_rounded,
                title: "عنواني المسجل",
                subtitle: "استخدام الموقع المخزن في حسابك",
                onTap: () => Navigator.pop(context, 'registered')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.green.withOpacity(0.1), child: Icon(icon, color: Colors.green)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey[200]!)),
    );
  }

  void _showStoreDetailsBottomSheet(Map<String, dynamic> store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StoreDetailsBottomSheet(store: store),
    );
  }
}

class StoreDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> store;
  const StoreDetailsBottomSheet({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_rounded, color: Colors.green, size: 30),
                const SizedBox(width: 15),
                Expanded(child: Text(store['supermarketName'] ?? 'المتجر', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            _buildInfoRow(Icons.location_on_outlined, store['address'] ?? 'العنوان غير متاح'),
            _buildInfoRow(Icons.directions_walk, "يبعد عنك مسافة ${store['distance']} كم"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed(MarketplaceHomeScreen.routeName, arguments: {'storeId': store['id'], 'storeName': store['supermarketName']});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text("دخول المتجر وتصفح العروض", style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 15),
          Expanded(child: Text(text, style: TextStyle(fontSize: 10.sp))),
        ],
      ),
    );
  }
}
