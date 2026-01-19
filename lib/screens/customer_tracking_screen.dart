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

  // 🛡️ منطق الإلغاء الذكي (إرسال حالات مخصصة للـ EC2)
  Future<void> _handleSmartCancel(BuildContext context, String currentStatus) async {
    bool isAccepted = currentStatus != 'pending';
    
    // 1. تحديد الحالة التي ستُرسل للفايربيز
    String targetStatus = isAccepted 
        ? 'cancelled_by_user_after_accept' 
        : 'cancelled_by_user_before_accept';

    // 2. لو المندوب وافق، لازم نحذره الأول
    if (isAccepted) {
      bool confirm = await showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("تنبيه هام"),
            content: const Text("المندوب في طريقه إليك الآن. إلغاء الطلب في هذه المرحلة سيؤدي لخصم من نقاطك أو رصيد الكاش باك الخاص بك كتعويض للمندوب. هل تريد الاستمرار؟"),
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

      if (!confirm) return; // العميل كنسل فكرة الإلغاء
    }

    // 3. تحديث الفايربيز بالحالة المخصصة ليفهمها الـ EC2 لاحقاً
    try {
      await FirebaseFirestore.instance.collection('specialRequests').doc(orderId).update({
        'status': targetStatus,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'customer'
      });
      
      if (context.mounted) {
        Navigator.pop(context); // العودة للرئيسية
      }
    } catch (e) {
      debugPrint("Cancel Error: $e");
    }
  }

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
        
        // إذا تغيرت الحالة لأي نوع من الإلغاء أو التسليم، نخرج تلقائياً
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
                  iconTheme: const IconThemeData(color: Colors.black, size: 28),
                  title: Text("تتبع رحلة Aksab", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.black)),
                  centerTitle: true,
                ),
                body: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: driverLatLng ?? pickupLatLng,
                        initialZoom: 14.5,
                      ),
                      children: [
                        TileLayer(urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken'),
                        MarkerLayer(
                          markers: [
                            Marker(point: pickupLatLng, width: 50, height: 50, child: const Icon(Icons.location_on, color: Colors.green, size: 45)),
                            Marker(point: dropoffLatLng, width: 50, height: 50, child: const Icon(Icons.flag_circle, color: Colors.red, size: 45)),
                            if (driverLatLng != null)
                              Marker(point: driverLatLng, width: 75, height: 75, child: _buildDriverMarker(orderData['vehicleType'] ?? 'motorcycle')),
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
    double bottomPadding = MediaQuery.of(context).padding.bottom;
    double progress = 0.1;
    String statusDesc = "بانتظار قبول مندوب...";
    Color progressColor = Colors.orange;

    if (status == 'accepted') { progress = 0.4; statusDesc = "المندوب في طريقه للاستلام"; progressColor = Colors.blue; }
    else if (status == 'at_pickup') { progress = 0.5; statusDesc = "المندوب وصل لموقع الاستلام"; progressColor = Colors.blueAccent; }
    else if (status == 'picked_up') { progress = 0.8; statusDesc = "جاري التوصيل الآن"; progressColor = Colors.green; }
    else if (status == 'delivered') { progress = 1.0; statusDesc = "تم التسليم بنجاح ✅"; progressColor = Colors.green[800]!; }

    return Positioned(
      bottom: bottomPadding + 10, left: 12, right: 12,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.grey[200], color: progressColor))),
                const SizedBox(width: 15),
                Text("${(progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text(statusDesc, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: progressColor)),
            const Divider(height: 25),

            if (status == 'accepted' || status == 'at_pickup')
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security, color: Colors.amber),
                    const SizedBox(width: 10),
                    Text("كود التسليم: ", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                    Text(code, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.red[900])),
                  ],
                ),
              ),

            Row(
              children: [
                CircleAvatar(radius: 25, backgroundColor: Colors.grey[100], child: Icon(Icons.person, size: 30, color: Colors.blue[900])),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver != null ? driver['fullname'] : "بحث عن مندوب...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      const Text("موثق عبر Aksab", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                ),
                if (driver != null)
                  IconButton(onPressed: () => _makePhoneCall(driver['phone']), icon: const Icon(Icons.phone, color: Colors.green, size: 30)),
              ],
            ),
            
            // ❌ زر الإلغاء الجديد والواضح جداً
            if (status == 'pending' || status == 'accepted' || status == 'at_pickup')
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _handleSmartCancel(context, status),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey[300]!))
                    ),
                    child: const Text("إلغاء الطلب نهائياً", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverMarker(String vehicleType) {
    IconData icon = Icons.delivery_dining;
    if (vehicleType == "pickup" || vehicleType == "ربع نقل") icon = Icons.local_shipping;
    if (vehicleType == "jumbo" || vehicleType == "جامبو") icon = Icons.fire_truck;
    return Column(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue[900], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: Icon(icon, color: Colors.white, size: 20)),
      const Icon(Icons.arrow_drop_down, color: Colors.blue, size: 20),
    ]);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }
}
