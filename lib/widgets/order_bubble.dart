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

  Future<void> _clearOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_special_order_id');
    BubbleService.hide();
  }

  // 🛡️ إصلاح الشاشة السوداء: الترتيب الصحيح (قفل الديالوج -> تحديث الداتا -> العودة للرئيسية)
  Future<void> _handleSmartCancelFromBubble(String currentStatus) async {
    bool isAccepted = currentStatus != 'pending';
    String targetStatus = isAccepted 
        ? 'cancelled_by_user_after_accept' 
        : 'cancelled_by_user_before_accept';

    try {
      // 1. تحديث فايربيز أولاً
      await FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).update({
        'status': targetStatus,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'customer'
      });
      
      if (mounted) {
        // 2. العودة للشاشة الرئيسية فوراً لتنظيف الـ Stack (تجنب السواد)
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAccepted ? "تم الإلغاء (سيتم مراجعة نقاطك)" : "تم إلغاء الطلب بنجاح"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }

      // 3. مسح البيانات المحلية وإخفاء الفقاعة (آخر خطوة لضمان ثبات الخريطة أثناء القفل)
      await _clearOrder();

    } catch (e) {
      debugPrint("Bubble Cancel Error: $e");
    }
  }

  IconData _getVehicleIcon(String? vehicleType) {
    switch (vehicleType) {
      case 'pickup': return Icons.local_shipping;
      case 'jumbo': return Icons.fire_truck;
      default: return Icons.delivery_dining;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();

        var data = snapshot.data!.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'pending';
        String? vehicleType = data['vehicleType'];

        if (status.contains('cancelled') || 
            status == 'delivered' || 
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
                  position = Offset(details.offset.dx.clamp(5.w, 82.w), details.offset.dy.clamp(10.h, 85.h));
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
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    bool isTrackingPageOpen = false;
    navState.popUntil((route) {
      if (route.settings.name == '/customerTracking') {
        isTrackingPageOpen = true;
      }
      return true; 
    });

    if (isTrackingPageOpen) {
      navState.pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      navState.push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/customerTracking'),
          builder: (context) => CustomerTrackingScreen(orderId: widget.orderId),
        ),
      );
    }
  }

  void _showOptionsDialog(BuildContext context, String status) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("إدارة الطلب", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text(status != 'pending'
            ? "⚠️ المندوب قبل الطلب. إلغاء الطلب الآن قد يخصم من نقاطك. هل تريد الاستمرار؟" 
            : "هل تريد إلغاء الطلب نهائياً أم إخفاء هذه الفقاعة فقط؟", style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // ✅ أولاً: نقفل الديالوج بـ context الخاص به
                _handleSmartCancelFromBubble(status); // ثانياً: ننظف الـ Stack ونلغي الطلب
              },
              child: const Text("إلغاء الطلب نهائياً", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); 
                _clearOrder(); 
              },
              child: const Text("إخفاء من الشاشة فقط", style: TextStyle(fontFamily: 'Cairo')),
            ),
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("رجوع", style: TextStyle(fontFamily: 'Cairo'))),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleUI(bool isAccepted, bool isDragging, String? vehicleType) {
    return Container(
      width: 16.w, height: 16.w,
      decoration: BoxDecoration(
        gradient: isAccepted ? null : RadialGradient(colors: [Colors.orange[800]!, Colors.orange[900]!], radius: 0.8),
        color: isAccepted ? Colors.green[700] : null,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isAccepted ? Colors.green : Colors.orange).withOpacity(0.5), 
            blurRadius: 15,
            spreadRadius: 2
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white30)
              )
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAccepted ? _getVehicleIcon(vehicleType) : Icons.radar, 
                color: Colors.white, 
                size: 20.sp
              ),
              if (!isAccepted)
                Text(
                  "جاري البحث", 
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 6.5.sp, 
                    fontWeight: FontWeight.bold, 
                    decoration: TextDecoration.none,
                    fontFamily: 'Cairo'
                  )
                ),
            ],
          ),
        ],
      ),
    );
  }
}
