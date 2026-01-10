import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import '../../providers/buyer_data_provider.dart';

class GiftsTab extends StatelessWidget {
  const GiftsTab({super.key});

  bool _checkIfInZone(double lat, double lng, List<dynamic> polygonPoints) {
    bool isInside = false;
    var j = polygonPoints.length - 1;
    for (var i = 0; i < polygonPoints.length; i++) {
      if (((polygonPoints[i]['lng'] > lng) != (polygonPoints[j]['lng'] > lng)) &&
          (lat < (polygonPoints[j]['lat'] - polygonPoints[i]['lat']) * (lng - polygonPoints[i]['lng']) / (polygonPoints[j]['lng'] - polygonPoints[i]['lng']) + polygonPoints[i]['lat'])) {
        isInside = !isInside;
      }
      j = i;
    }
    return isInside;
  }

  Future<List<Map<String, dynamic>>> _fetchGiftsWithLocationFilter(BuildContext context) async {
    final buyerProv = Provider.of<BuyerDataProvider>(context, listen: false);
    
    // ✅ العودة للمسميات الأصلية التي يستخدمها الـ BuyerDataProvider الخاص بك
    final userLat = buyerProv.latitude ?? 0.0;
    final userLng = buyerProv.longitude ?? 0.0;

    final giftsSnap = await FirebaseFirestore.instance
        .collection('giftPromos')
        .where('status', isEqualTo: 'active')
        .get();

    List<Map<String, dynamic>> finalGifts = [];
    Set<String> uniqueSellerIds = giftsSnap.docs.map((d) => d['sellerId'] as String).toSet();
    Map<String, List<dynamic>> sellerZones = {};

    for (var sId in uniqueSellerIds) {
      final sDoc = await FirebaseFirestore.instance.collection('sellers').doc(sId).get();
      if (sDoc.exists && sDoc.data()?['deliveryAreas'] != null) {
        try {
          sellerZones[sId] = jsonDecode(sDoc.data()!['deliveryAreas']);
        } catch (e) {
          debugPrint("Error decoding: $e");
        }
      }
    }

    for (var doc in giftsSnap.docs) {
      final data = doc.data();
      final sId = data['sellerId'];
      if (sellerZones.containsKey(sId)) {
        bool isServiced = false;
        for (var zone in sellerZones[sId]!) {
          if (_checkIfInZone(userLat, userLng, zone['coords'])) {
            isServiced = true;
            break;
          }
        }
        if (isServiced) finalGifts.add(data);
      }
    }
    return finalGifts;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchGiftsWithLocationFilter(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final gifts = snapshot.data ?? [];
        if (gifts.isEmpty) return _buildNoGiftsView();

        return ListView.builder(
          padding: EdgeInsets.all(10.sp),
          itemCount: gifts.length,
          itemBuilder: (context, index) => _buildGiftTile(gifts[index]),
        );
      },
    );
  }

  Widget _buildGiftTile(Map<String, dynamic> gift) {
    return Card(
      margin: EdgeInsets.only(bottom: 10.sp),
      child: ListTile(
        leading: Icon(Icons.redeem, color: Colors.orange, size: 30.sp),
        title: Text(gift['giftProductName'] ?? 'هدية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        subtitle: Text("عرض من: ${gift['sellerName'] ?? 'المتجر'}", style: GoogleFonts.cairo()),
      ),
    );
  }

  Widget _buildNoGiftsView() {
    return Center(child: Text("لا توجد هدايا متاحة حالياً", style: GoogleFonts.cairo()));
  }
}
