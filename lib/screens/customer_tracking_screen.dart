import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerTrackingScreen extends StatelessWidget {
  final String orderId;
  const CustomerTrackingScreen({super.key, required this.orderId});

  final String mapboxToken = "pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        String? driverId = orderData['driverId'];

        GeoPoint pickup = orderData['pickupLocation'];
        GeoPoint dropoff = orderData['dropoffLocation'];
        LatLng pickupLatLng = LatLng(pickup.latitude, pickup.longitude);
        LatLng dropoffLatLng = LatLng(dropoff.latitude, dropoff.longitude);

        return StreamBuilder<DocumentSnapshot>(
          stream: (driverId != null && driverId.isNotEmpty)
              ? FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).snapshots()
              : const Stream.empty(),
          builder: (context, driverSnapshot) {
            Map<String, dynamic>? driverData;
            LatLng? driverLatLng;

            if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
              driverData = driverSnapshot.data!.data() as Map<String, dynamic>;
              if (driverData != null && driverData.containsKey('location')) {
                GeoPoint dLoc = driverData['location'];
                driverLatLng = LatLng(dLoc.latitude, dLoc.longitude);
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                appBar: AppBar(
                  title: Text("تتبع الطلب #${orderId.substring(0, 5)}", 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp)),
                  centerTitle: true,
                  elevation: 0,
                ),
                body: Stack(
                  children: [
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
                            // مكان الاستلام (Pin صغير واحترافي)
                            Marker(
                              point: pickupLatLng,
                              width: 35, height: 35,
                              child: const Icon(Icons.location_on, color: Colors.green, size: 30),
                            ),
                            // مكان التسليم
                            Marker(
                              point: dropoffLatLng,
                              width: 35, height: 35,
                              child: const Icon(Icons.flag_circle, color: Colors.red, size: 30),
                            ),
                            // المندوب
                            if (driverLatLng != null)
                              Marker(
                                point: driverLatLng,
                                width: 50, height: 50,
                                child: _buildDriverMarker(orderData['vehicleType'] ?? 'motorcycle'),
                              ),
                          ],
                        ),
                      ],
                    ),
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

  Widget _buildDriverMarker(String vehicleType) {
    IconData icon = Icons.delivery_dining;
    if (vehicleType == "pickup") icon = Icons.local_shipping;
    if (vehicleType == "jumbo") icon = Icons.fire_truck;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 1)],
      ),
      child: Icon(icon, color: Colors.blue[900], size: 28),
    );
  }

  Widget _buildBottomPanel(String status, Map<String, dynamic> order, Map<String, dynamic>? driver) {
    return Positioned(
      bottom: 20, left: 15, right: 15,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 15,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statusStepper(status),
              const Divider(height: 30),
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blue[50],
                    child: Icon(Icons.person, color: Colors.blue[900]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver != null ? driver['fullname'] : "جاري البحث عن مندوب...",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp),
                        ),
                        Text(
                          "التكلفة: ${order['price']} ج.م",
                          style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 10.sp),
                        ),
                      ],
                    ),
                  ),
                  if (driver != null && (status == 'accepted' || status == 'delivered'))
                    IconButton(
                      icon: const Icon(Icons.phone_in_talk, color: Colors.green, size: 30),
                      onPressed: () => _makePhoneCall(driver['phone']),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusStepper(String status) {
    bool isAccepted = status == 'accepted' || status == 'delivered';
    bool isDelivered = status == 'delivered';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _stepItem("تم الطلب", true),
        _stepLine(isAccepted),
        _stepItem("تم القبول", isAccepted),
        _stepLine(isDelivered),
        _stepItem("وصلنا", isDelivered),
      ],
    );
  }

  Widget _stepItem(String title, bool active) {
    return Column(
      children: [
        Icon(active ? Icons.check_circle : Icons.radio_button_off,
            color: active ? Colors.blue[900] : Colors.grey[300], size: 18),
        Text(title, style: TextStyle(fontSize: 7.sp, color: active ? Colors.black : Colors.grey)),
      ],
    );
  }

  Widget _stepLine(bool active) => Expanded(
    child: Container(height: 2, color: active ? Colors.blue[900] : Colors.grey[200], margin: const EdgeInsets.only(bottom: 12)),
  );

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }
}

