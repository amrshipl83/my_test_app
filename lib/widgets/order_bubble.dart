// lib/widgets/order_bubble.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import '../screens/customer_tracking_screen.dart';
import '../services/bubble_service.dart';
import '../main.dart'; 

class OrderBubble extends StatefulWidget {
  final String orderId;
  const OrderBubble({super.key, required this.orderId});

  @override
  State<OrderBubble> createState() => _OrderBubbleState();
}

class _OrderBubbleState extends State<OrderBubble> with SingleTickerProviderStateMixin {
  Offset position = Offset(80.w, 70.h);
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // دالة مسح الطلب محلياً وإخفاء الفقاعة
  Future<void> _clearOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_special_order_id');
    BubbleService.hide();
  }

  // 🗑️ دالة إلغاء الطلب من طرف العميل في الفايربيز
  Future<void> _cancelOrderInFirebase() async {
    try {
      await FirebaseFirestore.instance
          .collection('specialRequests')
          .doc(widget.orderId)
          .update({'status': 'cancelled'});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم إلغاء الطلب بنجاح"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("Error cancelling order: $e");
    }
  }

  IconData _getVehicleIcon(String? vehicleType) {
    switch (vehicleType) {
      case 'pickup': return Icons.local_shipping;
      case 'jumbo': return Icons.fire_truck;
      case 'motorcycle':
      default: return Icons.delivery_dining;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('specialRequests')
          .doc(widget.orderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'pending';
        String? vehicleType = data['vehicleType'];

        // 🛑 التحديث الذكي: الإخفاء التلقائي عند انتهاء الطلب أو عدم توفر مناديب
        if (status == 'delivered' || 
            status == 'cancelled' || 
            status == 'rejected' || 
            status == 'no_drivers_available' || 
            status == 'expired') {
          Future.microtask(() => _clearOrder());
          return const SizedBox.shrink();
        }

        bool isAccepted = status != 'pending';

        return Positioned(
          left: position.dx,
          top: position.dy,
          child: Material(
            type: MaterialType.transparency,
            child: Draggable(
              feedback: _buildBubbleUI(isAccepted, true, vehicleType),
              childWhenDragging: const SizedBox.shrink(),
              onDragEnd: (details) {
                setState(() {
                  position = Offset(
                    details.offset.dx.clamp(5.w, 82.w),
                    details.offset.dy.clamp(10.h, 85.h),
                  );
                });
              },
              child: GestureDetector(
                onTap: () => _handleBubbleTap(context),
                onLongPress: () => _showOptionsDialog(context, status),
                child: isAccepted
                    ? _buildBubbleUI(isAccepted, false, vehicleType)
                    : ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.1).animate(_pulseController),
                        child: _buildBubbleUI(isAccepted, false, vehicleType),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleBubbleTap(BuildContext context) {
    bool isAlreadyOpen = false;
    navigatorKey.currentState?.popUntil((route) {
      if (route.settings.name == '/customerTracking') isAlreadyOpen = true;
      return true;
    });

    if (isAlreadyOpen) {
      navigatorKey.currentState?.pop();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/customerTracking'),
          builder: (context) => CustomerTrackingScreen(orderId: widget.orderId),
        ),
      );
    }
  }

  void _showOptionsDialog(BuildContext context, String status) {
    bool canCancel = status == 'pending'; 

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("إدارة الطلب الحالي"),
        content: Text(canCancel 
          ? "هل تريد إلغاء الطلب نهائياً أم إخفاء الفقاعة فقط؟" 
          : "الطلب قيد التنفيذ الآن. يمكنك إخفاء الفقاعة من شاشتك فقط."),
        actions: [
          if (canCancel)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _cancelOrderInFirebase(); 
              },
              child: const Text("إلغاء الطلب نهائياً", 
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearOrder(); 
            },
            child: const Text("إخفاء الفقاعة فقط"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("رجوع", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleUI(bool isAccepted, bool isDragging, String? vehicleType) {
    return Container(
      width: 16.w,
      height: 16.w,
      decoration: BoxDecoration(
        gradient: isAccepted 
            ? null 
            : RadialGradient(
                colors: [Colors.orange[800]!, Colors.orange[900]!],
                center: Alignment.center,
                radius: 0.8,
              ),
        color: isAccepted ? Colors.green[700] : null,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isAccepted ? Colors.green : Colors.orange).withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!isAccepted)
            const SizedBox(
              width: 50, height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAccepted ? _getVehicleIcon(vehicleType) : Icons.radar,
                color: Colors.white,
                size: 20.sp,
              ),
              if (!isAccepted)
                Text(
                  "جاري البحث",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 6.5.sp,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
