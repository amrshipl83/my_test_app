import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerTrackingScreen extends StatelessWidget {
  final String orderId;
  const CustomerTrackingScreen({super.key, required this.orderId});

  // توكن Mapbox الخاص بك
  final String mapboxToken = "pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      // المرحلة الأولى: مراقبة وثيقة الطلب
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        String? driverId = orderData['driverId'];

        // إحداثيات المواقع من الطلب
        GeoPoint pickup = orderData['pickupLocation'];
        GeoPoint dropoff = orderData['dropoffLocation'];
        LatLng pickupLatLng = LatLng(pickup.latitude, pickup.longitude);
        LatLng dropoffLatLng = LatLng(dropoff.latitude, dropoff.longitude);

        // المرحلة الثانية: مراقبة بيانات المندوب من مجموعة freeDrivers إذا تم قبول الطلب
        return StreamBuilder<DocumentSnapshot>(
          stream: (driverId != null && driverId.isNotEmpty)
              ? FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).snapshots()
              : const Stream.empty(),
          builder: (context, driverSnapshot) {
            Map<String, dynamic>? driverData;
            LatLng? driverLatLng;

            if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
              driverData = driverSnapshot.data!.data() as Map<String, dynamic>;
              if (driverData.containsKey('location')) {
                GeoPoint dLoc = driverData['location'];
                driverLatLng = LatLng(dLoc.latitude, dLoc.longitude);
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text("تتبع خط سير الطلب", style: TextStyle(fontWeight: FontWeight.w900)),
                  centerTitle: true,
                ),
                body: Stack(
                  children: [
                    // الخريطة
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: driverLatLng ?? pickupLatLng,
                        initialZoom: 14.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken',
                          additionalOptions: {'accessToken': mapboxToken},
                        ),
                        MarkerLayer(
                          markers: [
                            // مكان الاستلام
                            Marker(
                              point: pickupLatLng,
                              width: 45, height: 45,
                              child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                            ),
                            // مكان التسليم
                            Marker(
                              point: dropoffLatLng,
                              width: 45, height: 45,
                              child: const Icon(Icons.flag_circle, color: Colors.red, size: 40),
                            ),
                            // المندوب (يتحرك لايف)
                            if (driverLatLng != null)
                              Marker(
                                point: driverLatLng,
                                width: 55, height: 55,
                                child: _buildDriverMarker(orderData['vehicleType'] ?? 'motorcycle'),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // لوحة المعلومات السفلية
                    _buildBottomPanel(status, orderData, driverData),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // أيقونة المندوب حسب نوع المركبة
  Widget _buildDriverMarker(String vehicleType) {
    IconData icon = Icons.delivery_dining;
    if (vehicleType == "pickup") icon = Icons.local_shipping;
    if (vehicleType == "jumbo") icon = Icons.fire_truck;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
      ),
      child: Icon(icon, color: Colors.blue[900], size: 35),
    );
  }

  Widget _buildBottomPanel(String status, Map<String, dynamic> order, Map<String, dynamic>? driver) {
    return Positioned(
      bottom: 25, left: 15, right: 15,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 20,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // الـ Stepper العلوي للحالات
              _statusStepper(status),
              const Divider(height: 35, thickness: 1),
              
              // بيانات المندوب
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue[50],
                    child: Text(
                      driver != null ? (driver['fullname'] as String)[0].toUpperCase() : "?",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900], fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver != null ? driver['fullname'] : "جاري البحث عن مندوب...",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "التكلفة: ${order['price']} ج.م",
                          style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w900, fontSize: 11.sp),
                        ),
                      ],
                    ),
                  ),
                  // زر الاتصال الهاتفي (يظهر فقط عند قبول الطلب)
                  if (driver != null && (status == 'accepted' || status == 'delivered'))
                    GestureDetector(
                      onTap: () => _makePhoneCall(driver['phone']),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.green[600], shape: BoxShape.circle),
                        child: const Icon(Icons.phone, color: Colors.white, size: 25),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // واجهة خطوات الطلب (Stepper)
  Widget _statusStepper(String status) {
    bool isAccepted = status == 'accepted' || status == 'delivered';
    bool isDelivered = status == 'delivered';

    return Row(
      children: [
        _stepItem("تم الطلب", true),
        _stepLine(isAccepted),
        _stepItem("تم القبول", isAccepted),
        _stepLine(isDelivered),
        _stepItem("تم التوصيل", isDelivered),
      ],
    );
  }

  Widget _stepItem(String title, bool active) {
    return Column(
      children: [
        Icon(active ? Icons.check_circle : Icons.circle_outlined, 
             color: active ? Colors.blue[900] : Colors.grey[400], size: 20),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 8.sp, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _stepLine(bool active) => Expanded(
    child: Container(height: 2, color: active ? Colors.blue[900] : Colors.grey[300], margin: const EdgeInsets.only(bottom: 15)),
  );

  // دالة الاتصال الهاتفي
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }
}
