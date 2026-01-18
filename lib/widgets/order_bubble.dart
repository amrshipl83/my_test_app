// lib/widgets/order_bubble.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import '../screens/customer_tracking_screen.dart';
import '../services/bubble_service.dart';
import '../main.dart'; // ضروري للوصول إلى navigatorKey

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

  Future<void> _clearOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_special_order_id');
    BubbleService.hide();
  }

  // 🎯 تحديد الأيقونة بناءً على نوع المركبة المختارة في الطلب
  IconData _getVehicleIcon(String? vehicleType) {
    switch (vehicleType) {
      case 'ربع نقل': return Icons.local_shipping;
      case 'جامبو': return Icons.fire_truck;
      case 'موتوسيكل':
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

        if (status == 'delivered' || status == 'cancelled' || status == 'rejected') {
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
                onLongPress: () => _showOptionsDialog(context),
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
      if (route.settings.name == '/customerTracking') {
        isAlreadyOpen = true;
      }
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

  void _showOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إخفاء التتبع؟"),
        content: const Text("هل تريد إخفاء الفقاعة؟ لن يتم إلغاء طلبك الحالي."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              _clearOrder();
              Navigator.pop(ctx);
            },
            child: const Text("إخفاء", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ✅ التعديل الجديد لتحسين شكل "الرادار" ووضوح الفكرة
  Widget _buildBubbleUI(bool isAccepted, bool isDragging, String? vehicleType) {
    return Container(
      width: 16.w,
      height: 16.w,
      decoration: BoxDecoration(
        // تدرج لوني في حالة البحث لزيادة العمق
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
          // إضافة دائرة دوارة خفيفة جداً توحي بالبحث (الرادار)
          if (!isAccepted)
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAccepted ? _getVehicleIcon(vehicleType) : Icons.radar, // استخدام أيقونة رادار
                color: Colors.white,
                size: 20.sp,
              ),
              if (!isAccepted)
                Text(
                  "جاري البحث", // نص أوضح من "بحث.."
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
