import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerTrackingScreen extends StatelessWidget {
  static const routeName = '/customerTracking';
  final String orderId;

  const CustomerTrackingScreen({super.key, required this.orderId});

  final String mapboxToken = "pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw";

  Future<void> _handleSmartCancel(BuildContext context, String currentStatus) async {
    bool isAccepted = currentStatus != 'pending';
    String targetStatus = isAccepted 
        ? 'cancelled_by_user_after_accept' 
        : 'cancelled_by_user_before_accept';

    if (isAccepted) {
      bool confirm = await showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("تنبيه هام"),
            content: const Text("المندوب في طريقه إليك الآن. إلغاء الطلب في هذه المرحلة سيؤدي لخصم من نقاطك. هل تريد الاستمرار؟"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("تراجع")),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true), 
                child: const Text("تأكيد وإلغاء", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
              ),
            ],
          ),
        ),
      ) ?? false;
      if (!confirm) return;
    }

    try {
      await FirebaseFirestore.instance.collection('specialRequests').doc(orderId).update({
        'status': targetStatus,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'customer'
      });
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Cancel Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (orderId.isEmpty) return const Scaffold(body: Center(child: Text("طلب غير موجود")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        
        if (status.contains('cancelled') || status == 'delivered' || status == 'no_drivers_available') {
           WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          });
        }

        String? driverId = orderData['driverId'];
        String verificationCode = orderData['verificationCode'] ?? "----";
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
                extendBodyBehindAppBar: true,
                appBar: AppBar(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  elevation: 0,
                  title: Text("تتبع الرحلة", style: TextStyle(fontSize: 14.sp, color: Colors.black)),
                  centerTitle: true,
                ),
                body: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(initialCenter: driverLatLng ?? pickupLatLng, initialZoom: 14.5),
                      children: [
                        TileLayer(urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken'),
                        MarkerLayer(
                          markers: [
                            Marker(point: pickupLatLng, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 35)),
                            Marker(point: dropoffLatLng, width: 40, height: 40, child: const Icon(Icons.flag_circle, color: Colors.red, size: 35)),
                            if (driverLatLng != null)
                              Marker(point: driverLatLng, width: 60, height: 60, child: _buildDriverMarker(orderData['vehicleType'] ?? 'motorcycle')),
                          ],
                        ),
                      ],
                    ),
                    _buildUnifiedBottomPanel(context, status, orderData, driverData, verificationCode),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUnifiedBottomPanel(BuildContext context, String status, Map<String, dynamic> order, Map<String, dynamic>? driver, String code) {
    return Positioned(
      bottom: 20, left: 12, right: 12,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("حالة الطلب: $status", style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 10),
                Text(driver != null ? driver['fullname'] : "جاري البحث..."),
                const Spacer(),
                if (driver != null)
                  IconButton(onPressed: () => _makePhoneCall(driver['phone']), icon: const Icon(Icons.phone, color: Colors.green)),
              ],
            ),
            if (status == 'pending' || status == 'accepted')
              TextButton(onPressed: () => _handleSmartCancel(context, status), child: const Text("إلغاء الطلب", style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverMarker(String vehicleType) {
    return const Icon(Icons.delivery_dining, color: Colors.blue, size: 40);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }
}
