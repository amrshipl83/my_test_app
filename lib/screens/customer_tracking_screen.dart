// lib/screens/customer_tracking_screen.dart
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

  // 🛡️ منطق الإلغاء الذكي
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
            content: const Text("المندوب في طريقه إليك الآن. إلغاء الطلب الآن سيؤدي لخصم تعويض للمندوب من نقاطك. هل تريد الاستمرار؟"),
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
        
        // خروج تلقائي عند انتهاء الرحلة
        if (status.contains('cancelled') || status == 'delivered') {
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
                  iconTheme: const IconThemeData(color: Colors.black),
                  title: Text("تتبع الرحلة", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.black)),
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
                            Marker(point: pickupLatLng, width: 45, height: 45, child: const Icon(Icons.location_on, color: Colors.green, size: 40)),
                            Marker(point: dropoffLatLng, width: 45, height: 45, child: const Icon(Icons.flag_circle, color: Colors.red, size: 40)),
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
    double progress = 0.1;
    String statusDesc = "بانتظار قبول مندوب...";
    Color mainColor = Colors.orange;

    if (status == 'accepted') { progress = 0.4; statusDesc = "المندوب وافق وفي طريقه إليك"; mainColor = Colors.blue; }
    else if (status == 'at_pickup') { progress = 0.6; statusDesc = "المندوب وصل لموقع الاستلام"; mainColor = Colors.indigo; }
    else if (status == 'picked_up') { progress = 0.8; statusDesc = "جاري التوصيل الآن"; mainColor = Colors.green; }

    return Positioned(
      bottom: 15, left: 10, right: 10,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // شريط التقدم
            Row(
              children: [
                Expanded(child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.grey[200], color: mainColor)),
                const SizedBox(width: 10),
                Text("${(progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(statusDesc, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: mainColor)),
            const Divider(height: 25),

            // كود التسليم الذهبي
            if (status == 'accepted' || status == 'at_pickup' || status == 'picked_up')
              Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security, color: Colors.amber),
                    const SizedBox(width: 10),
                    const Text("كود التسليم: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(code, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.red[900])),
                  ],
                ),
              ),

            // بيانات المندوب والاتصال
            Row(
              children: [
                CircleAvatar(radius: 25, backgroundColor: Colors.blue[50], child: const Icon(Icons.person, color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver != null ? driver['fullname'] : "بحث عن مندوب...", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text("موثق من أكسب", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                if (driver != null)
                  IconButton(
                    onPressed: () async => await launchUrl(Uri.parse("tel:${driver['phone']}")),
                    icon: const Icon(Icons.phone_in_talk, color: Colors.green, size: 30),
                  ),
              ],
            ),
            
            // زر الإلغاء
            if (status == 'pending' || status == 'accepted' || status == 'at_pickup')
              Padding(
                padding: const EdgeInsets.top(10),
                child: TextButton(
                  onPressed: () => _handleSmartCancel(context, status),
                  child: const Text("إلغاء الطلب", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverMarker(String vehicleType) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.blue, width: 2)),
      child: const Icon(Icons.delivery_dining, color: Colors.blue, size: 30),
    );
  }
}
