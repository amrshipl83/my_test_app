// lib/screens/special_requests/abaatly_had_pro_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class AbaatlyHadProScreen extends StatefulWidget {
  final LatLng userCurrentLocation;
  final bool isStoreOwner; // لو true يبقى اللي بيطلب صاحب محل

  const AbaatlyHadProScreen({
    super.key, 
    required this.userCurrentLocation, 
    this.isStoreOwner = false
  });

  @override
  State<AbaatlyHadProScreen> createState() => _AbaatlyHadProScreenState();
}

class _AbaatlyHadProScreenState extends State<AbaatlyHadProScreen> {
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // لو صاحب محل، مكان الاستلام هو المحل بتاعه تلقائياً
    if (widget.isStoreOwner) {
      _pickupController.text = "موقعي الحالي (المحل)";
    } else {
      _dropoffController.text = "موقعي الحالي (المنزل)";
    }
  }

  Future<void> _submitOrder() async {
    if (_detailsController.text.isEmpty) return;
    setState(() => _isLoading = true);

    await FirebaseFirestore.instance.collection('specialRequests').add({
      'details': _detailsController.text,
      'pickupAddress': _pickupController.text,
      'dropoffAddress': _dropoffController.text,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'requestType': widget.isStoreOwner ? 'store_delivery' : 'consumer_personal',
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إرسال طلبك للمناديب 🚀")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ابعتلي حد (توصيل خاص)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInputBox("منين؟ (مكان الاستلام)", _pickupController, Icons.location_on, Colors.green),
            const Icon(Icons.arrow_downward, color: Colors.grey),
            _buildInputBox("لفين؟ (مكان التسليم)", _dropoffController, Icons.flag, Colors.red),
            const SizedBox(height: 20),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "اكتب تفاصيل الطلب (مثلاً: كرتونة مياه، أو مفاتيح..)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true, fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("تأكيد وطلب مندوب الآن", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBox(String label, TextEditingController controller, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 15),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: label, border: InputBorder.none),
            ),
          ),
          const Icon(Icons.map_outlined, color: Colors.blue, size: 20), // لفتح الخريطة لاحقاً
        ],
      ),
    );
  }
}
